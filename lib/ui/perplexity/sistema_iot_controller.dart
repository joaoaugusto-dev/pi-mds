import 'dart:convert';
import '../services/firebase_service.dart';
import '../services/funcionario_service.dart';
import '../services/log_service.dart';
import '../dao/historico_dao.dart';
// import de PreferenciaTagDao removido - preferências agora vêm da tabela `funcionarios`
import '../models/dados_sensores.dart';
import '../models/estado_climatizador.dart';
import '../models/preferencias_grupo.dart';
// Preferências individuais agora são lidas diretamente da tabela `funcionarios`.
import '../models/log_entry.dart';

class SistemaIotController {
  final FirebaseService firebaseService;
  final FuncionarioService funcionarioService;
  final LogService logService;
  final HistoricoDao historicoDao;
  // removido cache preferenciaTagDao — preferências vêm de `funcionarios`

  // Estados internos
  DadosSensores? _ultimaSensorData;
  EstadoClimatizador? _ultimoEstadoClima;
  List<String> _ultimasTags = [];
  String _comandoIluminacaoAtual = 'auto';
  bool verbose =
      true; // controla se prints devem ser exibidos
  bool _bgRunning = false;
  Duration _bgInterval = Duration(seconds: 3);

  // Controle de duplicação
  DateTime? _ultimoTimestamp;
  String _ultimoHashTags = "";
  // Controle de climatizador removido - ESP32 tem controle total da automação física

  SistemaIotController({
    required this.firebaseService,
    required this.funcionarioService,
    required this.logService,
    required this.historicoDao,
  });

  // Getters para estado atual
  DadosSensores? get ultimaSensorData =>
      _ultimaSensorData;
  EstadoClimatizador? get ultimoEstadoClima =>
      _ultimoEstadoClima;
  String get comandoIluminacaoAtual =>
      _comandoIluminacaoAtual;

  // Processar solicitações de preferências do ESP32
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

        // Parse da solicitação
        Map<String, dynamic> requestJson =
            jsonDecode(requestData);
        List<String> tags = List<String>.from(
          requestJson['tags'] ?? [],
        );

        if (tags.isNotEmpty) {
          // Calcular preferências
          PreferenciasGrupo? prefs =
              await processarSolicitacaoPreferencias(
                tags,
              );

          if (prefs != null) {
            // Publicar resposta no Firebase para o ESP32 ler
            await firebaseService
                .salvarPreferenciasGrupo(
                  prefs.toJson(),
                );
            _log(
              '✓ Preferências respondidas para ESP32: Temp=${prefs.temperaturaMedia?.toStringAsFixed(1)}°C, Lum=${prefs.luminosidadeUtilizada}%',
            );
          }
        }

        // Limpar a solicitação processada
        await firebaseService
            .limparPreferenciasRequest();
      }
    } catch (e) {
      _log(
        '✗ Erro ao processar solicitação de preferências: $e',
      );
    }
  }

  // Processar dados dos sensores vindos do Firebase
  Future<void> processarDadosSensores() async {
    DadosSensores? novosDados =
        await firebaseService.lerSensores();

    if (novosDados != null &&
        novosDados.dadosValidos) {
      // Verificar se são dados realmente novos
      DateTime novoTimestamp =
          novosDados.timestamp;
      String novoHashTags = novosDados.tags.join(
        ',',
      );

      // Se timestamp é o mesmo E as tags são as mesmas, pular processamento
      if (_ultimoTimestamp == novoTimestamp &&
          _ultimoHashTags == novoHashTags) {
        _log(
          '⏩ Dados idênticos ignorados (timestamp: $novoTimestamp, tags: $novoHashTags)',
        );
        return;
      }

      // Verificar mudanças nas tags para logs APENAS se as tags mudaram E passou tempo suficiente
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

      // Atualizar estados de controle
      _ultimoTimestamp = novoTimestamp;
      _ultimoHashTags = novoHashTags;
      _ultimaSensorData = novosDados;
      _ultimasTags = List.from(novosDados.tags);

      // Qual valor de iluminação salvar no histórico?
      // Preferimos o valor reportado pelos sensores (estado real do sistema).
      // Isso evita enviar para o MySQL o "valor que seria" em modo automático
      // quando o sistema está operando em modo manual.
      int iluminacaoArtificial =
          novosDados.iluminacaoArtificial;
      // Fallback: se o dispositivo não reporta a iluminação artificial (0 por padrão)
      // e estivermos efetivamente em modo manual no servidor, usar o comando atual.
      if (iluminacaoArtificial == 0 &&
          novosDados.tags.isNotEmpty &&
          _comandoIluminacaoAtual != 'auto') {
        iluminacaoArtificial =
            int.tryParse(
              _comandoIluminacaoAtual,
            ) ??
            0;
      }

      // Salvar no histórico MySQL para Power BI
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

      // Aplicar automação se não estiver em modo manual
      // Aplicar automação (lógica interna decide se aplica iluminação/clima)
      await _aplicarAutomacao(novosDados);

      _log('✓ Dados processados: $novosDados');
    }
  }

  // Aplicar automação baseada em preferências
  Future<void> _aplicarAutomacao(
    DadosSensores dados,
  ) async {
    if (dados.tags.isEmpty) {
      // Sem pessoas: desligar iluminação (aplicar apenas se não houver intervenção manual)
      if (_comandoIluminacaoAtual == 'auto') {
        await _aplicarAutomacaoIluminacao(0);
      }
      return;
    }

    // Processar preferências primeiro (MySQL/Dart)
    PreferenciasGrupo? preferencias =
        await processarSolicitacaoPreferencias(
          dados.tags,
        );

    // Se por algum motivo não foi possível calcular via MySQL, usar o método
    // existente como fallback (mantém compatibilidade).
    if (preferencias == null) {
      preferencias = await funcionarioService
          .calcularPreferenciasGrupo(dados.tags);
    }

    // Automação da iluminação — só aplicar se o comando atual estiver em 'auto'.
    if (_comandoIluminacaoAtual == 'auto') {
      await _aplicarAutomacaoIluminacao(
        preferencias.luminosidadeUtilizada,
      );
    }

    // Automação do climatizador
    // Observação: o servidor nunca envia comandos automáticos ao climatizador.
    // Portanto não aplicamos alteração aqui baseada em flags de modo manual.
  }

  // Processar solicitações de preferências: busca e cálculo via FuncionarioService
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

      // Publicar no Firebase para comunicação com o ESP
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

  // Processar estado do climatizador (ler Firebase)
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

  // Controles manuais - Iluminação
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

  // Controles manuais - Climatizador
  Future<bool> enviarComandoClimatizador(
    String comando,
  ) async {
    if (comando == 'auto') {
      print(
        '🔄 Climatizador voltou ao modo automático',
      );
      return true;
    }
    // Envia comando manual ao climatizador (servidor repassa ao ESP via Firebase)
    bool sucesso = await firebaseService
        .enviarComandoClimatizador(comando);

    if (sucesso) {
      _log('❄️ Comando climatizador: $comando');
    }

    return sucesso;
  }

  // Obter resumo do sistema
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

  // Background sync (silenciosa) - inicia loop que processa e salva dados
  void startBackgroundSync({
    Duration interval = const Duration(
      seconds: 3,
    ),
  }) {
    if (_bgRunning) return;
    _bgRunning = true;
    _bgInterval = interval;
    // rodar em uma task assíncrona
    () async {
      while (_bgRunning) {
        try {
          // Processar solicitações de preferências do ESP32 primeiro
          await processarSolicitacoesPreferenciasESP();

          // Processar dados e estado — estes métodos usam _log(), que respeita 'verbose'
          await processarDadosSensores();
          await processarEstadoClimatizador();
        } catch (e) {
          _log('Erro no background sync: $e');
        }
        await Future.delayed(_bgInterval);
      }
    }();
  }

  void stopBackgroundSync() {
    _bgRunning = false;
  }

  void setVerbose(bool v) {
    verbose = v;
  }

  void _log(String msg) {
    if (verbose) print(msg);
  }

  // Função auxiliar para 'snapping' de luminosidade para múltiplos de 25
  // _nivelValido está implementado em FuncionarioService e usado onde necessário.

  // Stream de dados em tempo real - intervalo maior para dashboard mais estável
  Stream<Map<String, dynamic>>
  streamDadosTempoReal() async* {
    while (true) {
      await processarDadosSensores();
      await processarEstadoClimatizador();
      yield obterResumoSistema();
      await Future.delayed(
        Duration(seconds: 8),
      ); // Aumentado para reduzir movimentação
    }
  }

  // Inicializar sistema
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
