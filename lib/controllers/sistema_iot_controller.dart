import 'dart:convert';
import 'dart:async';
import '../services/firebase_service.dart';
import '../services/funcionario_service.dart';
import '../services/log_service.dart';
import '../dao/historico_dao.dart';
import '../models/dados_sensores.dart';
import '../models/estado_climatizador.dart';
import '../models/preferencias_grupo.dart';
import '../models/log_entry.dart';

class SistemaIotController {
  final FirebaseService firebaseService;
  final FuncionarioService funcionarioService;
  final LogService logService;
  final HistoricoDao historicoDao;


  
  DadosSensores? _ultimaSensorData;
  EstadoClimatizador? _ultimoEstadoClima;
  List<String> _ultimasTags = [];
  String _comandoIluminacaoAtual = 'auto';
  bool verbose = true;
  bool _bgRunning = false;

  // Gerenciamento de Streams
  StreamSubscription<DadosSensores?>?
  _sensoresSubscription;
  StreamSubscription<EstadoClimatizador?>?
  _climatizadorSubscription;
  StreamSubscription<String?>?
  _preferenciasRequestSubscription;
  
  DateTime? _ultimoTimestamp;
  String _ultimoHashTags = "";


  SistemaIotController({
    required this.firebaseService,
    required this.funcionarioService,
    required this.logService,
    required this.historicoDao,
  });

  
  DadosSensores? get ultimaSensorData =>
      _ultimaSensorData;
  EstadoClimatizador? get ultimoEstadoClima =>
      _ultimoEstadoClima;
  String get comandoIluminacaoAtual =>
      _comandoIluminacaoAtual;

  
  Future<void>
  processarSolicitacoesPreferenciasESP() async {
    try {
      String? requestData = await firebaseService
          .lerPreferenciasRequest();

      if (requestData != null &&
          requestData.isNotEmpty &&
          requestData != 'null') {
        _log(
          '📨 Solicitação de preferências recebida do ESP32',
        );

        
        Map<String, dynamic> requestJson =
            jsonDecode(requestData);
        List<String> tags = List<String>.from(
          requestJson['tags'] ?? [],
        );

        if (tags.isNotEmpty) {
          
          PreferenciasGrupo? prefs =
              await processarSolicitacaoPreferencias(
                tags,
              );

          if (prefs != null) {
            
            await firebaseService
                .salvarPreferenciasGrupo(
                  prefs.toJson(),
                );
            _log(
              '✓ Preferências respondidas para ESP32: Temp=${prefs.temperaturaMedia?.toStringAsFixed(1)}°C, Lum=${prefs.luminosidadeUtilizada}%',
            );
          }
        }

        
        await firebaseService
            .limparPreferenciasRequest();
      }
    } catch (e) {
      _log(
        '✗ Erro ao processar solicitação de preferências: $e',
      );
    }
  }

  
  Future<void> processarDadosSensores() async {
    DadosSensores? novosDados =
        await firebaseService.lerSensores();

    if (novosDados != null &&
        novosDados.dadosValidos) {
      
      DateTime novoTimestamp =
          novosDados.timestamp;
      String novoHashTags = novosDados.tags.join(
        ',',
      );

      
      if (_ultimoTimestamp == novoTimestamp &&
          _ultimoHashTags == novoHashTags) {
        _log(
          '⏩ Dados idênticos ignorados (timestamp: $novoTimestamp, tags: $novoHashTags)',
        );
        return;
      }

      
      DateTime agora = DateTime.now();
      if (_ultimaSensorData != null &&
          _ultimoHashTags != novoHashTags &&
          (_ultimoTimestamp == null ||
              agora
                      .difference(
                        _ultimoTimestamp!,
                      )
                      .inSeconds >
                  3)) {
        List<LogEntry> logsGerados =
            await logService
                .processarMudancasTags(
                  _ultimasTags,
                  novosDados.tags,
                );
        if (logsGerados.isNotEmpty) {
          for (LogEntry log in logsGerados) {
            _log(
              '✓ Log ${log.tipo.toUpperCase()} registrado: ${log.nomeCompleto}',
            );
          }
        }
      }

      
      _ultimoTimestamp = novoTimestamp;
      _ultimoHashTags = novoHashTags;
      _ultimaSensorData = novosDados;
      _ultimasTags = List.from(novosDados.tags);

      
      int iluminacaoArtificial =
          novosDados.iluminacaoArtificial;
      
      if (iluminacaoArtificial == 0 &&
          novosDados.tags.isNotEmpty &&
          _comandoIluminacaoAtual != 'auto') {
        iluminacaoArtificial =
            int.tryParse(
              _comandoIluminacaoAtual,
            ) ??
            0;
      }

      
      await historicoDao.salvarDadosHistoricos(
        novosDados,
        climaLigado: _ultimoEstadoClima?.ligado,
        climaUmidificando:
            _ultimoEstadoClima?.umidificando,
        climaVelocidade:
            _ultimoEstadoClima?.velocidade,
        iluminacaoArtificial:
            iluminacaoArtificial,
      );

      
      await _aplicarAutomacao(novosDados);

      _log('✓ Dados processados: $novosDados');
    }
  }

  
  Future<void> _aplicarAutomacao(
    DadosSensores dados,
  ) async {
    if (dados.tags.isEmpty) {
    
      if (_comandoIluminacaoAtual == 'auto') {
        await _aplicarAutomacaoIluminacao(0);
      }
      return;
    }

    
    PreferenciasGrupo? preferencias =
        await processarSolicitacaoPreferencias(
          dados.tags,
        );

    
    preferencias ??= await funcionarioService
        .calcularPreferenciasGrupo(dados.tags);

    
    if (_comandoIluminacaoAtual == 'auto') {
      await _aplicarAutomacaoIluminacao(
        preferencias.luminosidadeUtilizada,
      );
    }

    
  }

  
  Future<PreferenciasGrupo?>
  processarSolicitacaoPreferencias(
    List<String> tags,
  ) async {
    if (tags.isEmpty) return null;

    _log(
      '\ud83d\udccb Processando preferencias via tabela funcionarios para tags: ${tags.join(', ')}',
    );

    try {
      PreferenciasGrupo prefs =
          await funcionarioService
              .calcularPreferenciasGrupo(tags);

      
      try {
        await firebaseService
            .salvarPreferenciasGrupo(
              prefs.toJson(),
            );
        _log(
          '\u2713 Preferencias do grupo publicadas no Firebase para o ESP',
        );
      } catch (_) {
        _log(
          '\u26a0 Falha ao publicar preferencias no Firebase (n\u00e3o crítico)',
        );
      }

      return prefs;
    } catch (e) {
      _log(
        '\u2717 Erro ao processar preferencias via funcionarios: $e',
      );
      return null;
    }
  }

  
  Future<void>
  processarEstadoClimatizador() async {
    try {
      EstadoClimatizador? novoEstado =
          await firebaseService.lerClimatizador();
      if (novoEstado != null) {
        _ultimoEstadoClima = novoEstado;
        _log(
          '\u2713 Estado climatizador: $novoEstado',
        );
      }
    } catch (e) {
      _log(
        '✗ Erro ao ler estado climatizador: $e',
      );
    }
  }

  Future<void> _aplicarAutomacaoIluminacao(
    int luminosidadeDesejada,
  ) async {
    String novoComando = luminosidadeDesejada
        .toString();
    if (_comandoIluminacaoAtual != novoComando) {
      await firebaseService
          .enviarComandoIluminacao(novoComando);
      _comandoIluminacaoAtual = novoComando;
      _log(
        '🔆 Automação iluminação: $luminosidadeDesejada%',
      );
    }
  }

  
  Future<bool> definirIluminacaoManual(
    dynamic nivel,
  ) async {
    if (nivel == 'auto') {
      _comandoIluminacaoAtual = 'auto';
      await firebaseService
          .enviarComandoIluminacao('auto');
      print(
        '🔄 Iluminação voltou ao modo automático',
      );
      return true;
    }

    int? nivelInt = int.tryParse(
      nivel.toString(),
    );
    if (nivelInt != null &&
        [0, 25, 50, 75, 100].contains(nivelInt)) {
      _comandoIluminacaoAtual = nivel.toString();
      await firebaseService
          .enviarComandoIluminacao(nivel);
      _log('🔆 Iluminação manual: $nivel%');
      return true;
    }

    print(
      '✗ Nível de iluminação inválido: $nivel',
    );
    return false;
  }

  
  Future<bool> enviarComandoClimatizador(
    String comando, {
    int? velocidade,
  }) async {
    
    final comandosValidos = [
      'auto',
      'power',
      'power_on',
      'power_off',
      'velocidade',
      'umidificar',
      'timer',
      'aleta_v',
      'aleta_h',
    ];

    if (!comandosValidos.contains(comando)) {
      print(
        '✗ Comando climatizador inválido: $comando',
      );
      return false;
    }

    if (comando == 'auto') {
      print(
        '🔄 Climatizador voltou ao modo automático',
      );
      return await firebaseService
          .enviarComandoClimatizador(comando);
    }

    
    if (_ultimoEstadoClima != null &&
        !_ultimoEstadoClima!.ligado) {
      if ([
        'velocidade',
        'umidificar',
        'timer',
        'aleta_v',
        'aleta_h',
      ].contains(comando)) {
        print(
          '⚠ Comando "$comando" requer que o climatizador esteja ligado',
        );
        print(
          '💡 Ligue o climatizador primeiro com o comando "power_on"',
        );
        return false;
      }
    }

    
    if (velocidade != null &&
        (velocidade < 1 || velocidade > 3)) {
      print(
        '⚠ Velocidade inválida: $velocidade (deve ser 1-3)',
      );
      return false;
    }

    
    bool sucesso = await firebaseService
        .enviarComandoClimatizador(
          comando,
          velocidade: velocidade,
        );

    if (sucesso) {
      String emoji = _getEmojiParaComando(
        comando,
      );
      String msg =
          '$emoji Comando climatizador: $comando';
      if (velocidade != null) {
        msg += ' (velocidade: $velocidade)';
      }
      _log(msg);
    }

    return sucesso;
  }

  String _getEmojiParaComando(String comando) {
    switch (comando) {
      case 'power':
      case 'power_on':
        return '💨';
      case 'power_off':
        return '💤';
      case 'velocidade':
        return '⚙️';
      case 'umidificar':
        return '💧';
      case 'timer':
        return '⏲️';
      case 'aleta_v':
        return '🔼';
      case 'aleta_h':
        return '↔️';
      default:
        return '❄️';
    }
  }

  
  Map<String, dynamic> obterResumoSistema() {
    return {
      'sensores': _ultimaSensorData?.toJson(),
      'climatizador': _ultimoEstadoClima
          ?.toJson(),
      'comando_iluminacao_atual':
          _comandoIluminacaoAtual,
      'tags_presentes': _ultimasTags,
      'timestamp': DateTime.now()
          .toIso8601String(),
    };
  }

  
  /// Inicia o monitoramento em tempo real usando Streams
  void startBackgroundSync({
    Duration interval = const Duration(
      seconds: 3,
    ),
  }) {
    if (_bgRunning) return;
    _bgRunning = true;
    
    _log(
      '🔄 Iniciando monitoramento em tempo real com Streams...',
    );

    // Stream de sensores
    _sensoresSubscription = firebaseService
        .streamSensores
        .listen(
          (dados) async {
            if (dados != null) {
              await _processarDadosSensoresStream(
                dados,
              );
            }
          },
          onError: (e) => _log(
            '✗ Erro no stream de sensores: $e',
          ),
        );

    // Stream do climatizador
    _climatizadorSubscription = firebaseService
        .streamClimatizador
        .listen(
          (estado) {
            if (estado != null) {
              _ultimoEstadoClima = estado;
              _log(
                '✓ Estado climatizador atualizado via stream: $estado',
              );
            }
          },
          onError: (e) => _log(
            '✗ Erro no stream do climatizador: $e',
          ),
        );

    // Stream de solicitações de preferências
    _preferenciasRequestSubscription = firebaseService
        .streamPreferenciasRequest
        .listen(
          (requestData) async {
            if (requestData != null &&
                requestData.isNotEmpty &&
                requestData != 'null') {
              _log(
                '📨 Solicitação de preferências recebida via stream',
              );
          await processarSolicitacoesPreferenciasESP();
            }
          },
          onError: (e) => _log(
            '✗ Erro no stream de preferências: $e',
          ),
        );

    _log('✓ Streams iniciados com sucesso!');
  }

  /// Para o monitoramento em tempo real e cancela as assinaturas
  void stopBackgroundSync() {
    if (!_bgRunning) return;

    _log(
      '⏹️ Parando monitoramento em tempo real...',
    );
    _bgRunning = false;

    _sensoresSubscription?.cancel();
    _climatizadorSubscription?.cancel();
    _preferenciasRequestSubscription?.cancel();

    firebaseService.stopAllStreams();

    _log('✓ Streams parados com sucesso!');
  }

  /// Processa dados dos sensores recebidos via stream
  Future<void> _processarDadosSensoresStream(
    DadosSensores novosDados,
  ) async {
    if (!novosDados.dadosValidos) return;

    // Verificar duplicatas
    DateTime novoTimestamp = novosDados.timestamp;
    String novoHashTags = novosDados.tags.join(
      ',',
    );

    if (_ultimoTimestamp == novoTimestamp &&
        _ultimoHashTags == novoHashTags) {
      return; // Dados duplicados, ignorar
    }

    // Processar mudanças de tags
    DateTime agora = DateTime.now();
    if (_ultimaSensorData != null &&
        _ultimoHashTags != novoHashTags &&
        (_ultimoTimestamp == null ||
            agora
                    .difference(_ultimoTimestamp!)
                    .inSeconds >
                3)) {
      List<LogEntry> logsGerados =
          await logService.processarMudancasTags(
            _ultimasTags,
            novosDados.tags,
          );
      if (logsGerados.isNotEmpty) {
        for (LogEntry log in logsGerados) {
          _log(
            '✓ Log ${log.tipo.toUpperCase()} registrado: ${log.nomeCompleto}',
          );
        }
      }
    }

    // Atualizar estado
    _ultimoTimestamp = novoTimestamp;
    _ultimoHashTags = novoHashTags;
    _ultimaSensorData = novosDados;
    _ultimasTags = List.from(novosDados.tags);

    // Salvar dados históricos
    int iluminacaoArtificial =
        novosDados.iluminacaoArtificial;
    if (iluminacaoArtificial == 0 &&
        novosDados.tags.isNotEmpty &&
        _comandoIluminacaoAtual != 'auto') {
      iluminacaoArtificial =
          int.tryParse(_comandoIluminacaoAtual) ??
          0;
    }

    await historicoDao.salvarDadosHistoricos(
      novosDados,
      climaLigado: _ultimoEstadoClima?.ligado,
      climaUmidificando:
          _ultimoEstadoClima?.umidificando,
      climaVelocidade:
          _ultimoEstadoClima?.velocidade,
      iluminacaoArtificial: iluminacaoArtificial,
    );

    // Aplicar automação
    await _aplicarAutomacao(novosDados);

    _log(
      '✓ Dados processados via stream: $novosDados',
    );
  }

  void setVerbose(bool v) {
    verbose = v;
  }

  void _log(String msg) {
    if (verbose) print(msg);
  }

  /// Libera recursos quando o controller não é mais necessário
  void dispose() {
    stopBackgroundSync();
    firebaseService.dispose();
  }

  

  /// Stream de dados em tempo real do sistema completo
  Stream<Map<String, dynamic>>
  streamDadosTempoReal() {
    return firebaseService.streamSensores.asyncMap((
      _,
    ) async {
      // Quando sensores atualizam, buscar estado do climatizador também
      await processarEstadoClimatizador();
      return obterResumoSistema();
    });
  }

  
  Future<void> inicializar() async {
    print('🚀 Inicializando Sistema IoT...');

    // Primeira leitura
    await processarDadosSensores();
    await processarEstadoClimatizador();

    print(
      '✓ Sistema IoT inicializado com sucesso!',
    );
  }
}
