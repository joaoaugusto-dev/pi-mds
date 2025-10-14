import 'dart:convert';
import '../services/firebase_service.dart';
import '../services/funcionario_service.dart';
import '../services/log_service.dart';
import '../dao/historico_dao.dart';
import '../dao/preferencia_tag_dao.dart';
import '../models/dados_sensores.dart';
import '../models/estado_climatizador.dart';
import '../models/preferencias_grupo.dart';
import '../models/preferencia_tag.dart';
import '../models/log_entry.dart';

class SistemaIotController {
  final FirebaseService firebaseService;
  final FuncionarioService funcionarioService;
  final LogService logService;
  final HistoricoDao historicoDao;
  final PreferenciaTagDao preferenciaTagDao;

  // Estados internos
  DadosSensores? _ultimaSensorData;
  EstadoClimatizador? _ultimoEstadoClima;
  List<String> _ultimasTags = [];
  bool _modoManualIluminacao = false;
  bool _modoManualClimatizador = false;
  String _comandoIluminacaoAtual = 'auto';
  bool verbose = true; // controla se prints devem ser exibidos
  bool _bgRunning = false;
  Duration _bgInterval = Duration(seconds: 3);

  // Controle de duplicação
  DateTime? _ultimoTimestamp;
  String _ultimoHashTags = "";
  // Controle para evitar reenvio repetido de comandos ao climatizador
  String? _ultimoComandoClimatizador;
  int _tsUltimoComandoClimatizador = 0; // epoch ms
  final int _cooldownComandoClimatizadorMs = 15 * 1000; // 15s

  SistemaIotController({
    required this.firebaseService,
    required this.funcionarioService,
    required this.logService,
    required this.historicoDao,
    required this.preferenciaTagDao,
  });

  // Getters para estado atual
  DadosSensores? get ultimaSensorData => _ultimaSensorData;
  EstadoClimatizador? get ultimoEstadoClima => _ultimoEstadoClima;
  bool get modoManualIluminacao => _modoManualIluminacao;
  bool get modoManualClimatizador => _modoManualClimatizador;
  String get comandoIluminacaoAtual => _comandoIluminacaoAtual;

  // Processar solicitações de preferências do ESP32
  Future<void> processarSolicitacoesPreferenciasESP() async {
    try {
      String? requestData = await firebaseService.lerPreferenciasRequest();

      if (requestData != null &&
          requestData.isNotEmpty &&
          requestData != 'null') {
        _log('📨 Solicitação de preferências recebida do ESP32');

        // Parse da solicitação
        Map<String, dynamic> requestJson = jsonDecode(requestData);
        List<String> tags = List<String>.from(requestJson['tags'] ?? []);

        if (tags.isNotEmpty) {
          // Calcular preferências
          PreferenciasGrupo? prefs = await processarSolicitacaoPreferencias(
            tags,
          );

          if (prefs != null) {
            // Publicar resposta no Firebase para o ESP32 ler
            await firebaseService.salvarPreferenciasGrupo(prefs.toJson());
            _log(
              '✓ Preferências respondidas para ESP32: Temp=${prefs.temperaturaMedia?.toStringAsFixed(1)}°C, Lum=${prefs.luminosidadeUtilizada}%',
            );
          }
        }

        // Limpar a solicitação processada
        await firebaseService.limparPreferenciasRequest();
      }
    } catch (e) {
      _log('✗ Erro ao processar solicitação de preferências: $e');
    }
  }

  // Processar dados dos sensores vindos do Firebase
  Future<void> processarDadosSensores() async {
    DadosSensores? novosDados = await firebaseService.lerSensores();

    if (novosDados != null && novosDados.dadosValidos) {
      // Verificar se são dados realmente novos
      DateTime novoTimestamp = novosDados.timestamp;
      String novoHashTags = novosDados.tags.join(',');

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
              agora.difference(_ultimoTimestamp!).inSeconds > 3)) {
        List<LogEntry> logsGerados = await logService.processarMudancasTags(
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

      // Salvar no histórico MySQL para Power BI
      await historicoDao.salvarDadosHistoricos(
        novosDados,
        climaLigado: _ultimoEstadoClima?.ligado,
        climaUmidificando: _ultimoEstadoClima?.umidificando,
        climaVelocidade: _ultimoEstadoClima?.velocidade,
        modoManualIlum: _modoManualIluminacao,
        modoManualClima: _modoManualClimatizador,
      );

      // Aplicar automação se não estiver em modo manual
      if (!_modoManualIluminacao && !_modoManualClimatizador) {
        await _aplicarAutomacao(novosDados);
      }

      _log('✓ Dados processados: $novosDados');
    }
  }

  // Processar estado do climatizador
  Future<void> processarEstadoClimatizador() async {
    EstadoClimatizador? novoEstado = await firebaseService.lerClimatizador();

    if (novoEstado != null) {
      _ultimoEstadoClima = novoEstado;
      _log('✓ Estado climatizador: $novoEstado');
    }
  }

  // Processar solicitação de preferências: buscar no MySQL e calcular médias em Dart.
  // Retorna um objeto PreferenciasGrupo (ou null em caso de erro).
  Future<PreferenciasGrupo?> processarSolicitacaoPreferencias(
    List<String> tags,
  ) async {
    if (tags.isEmpty) return null;

    _log(
      '\ud83d\udccb Processando preferências (MySQL) para tags: ${tags.join(', ')}',
    );

    try {
      // Buscar preferências individuais diretamente no MySQL (cache local)
      List<PreferenciaTag> preferencias = await preferenciaTagDao
          .buscarMultiplasTags(tags);

      // Mapear tags encontradas
      var encontrados = <String, PreferenciaTag>{};
      for (var p in preferencias) {
        encontrados[p.tag] = p;
      }

      List<String> tagsDesconhecidas = [];
      List<Map<String, dynamic>> funcionariosPresentes = [];

      double somaTemp = 0.0;
      int somaLum = 0;
      int countTemp = 0;
      int countLum = 0;

      for (String tag in tags) {
        if (encontrados.containsKey(tag)) {
          var pref = encontrados[tag]!;
          // Considerar apenas valores válidos
          if (pref.temperaturaPreferida >= 16 &&
              pref.temperaturaPreferida <= 32) {
            somaTemp += pref.temperaturaPreferida;
            countTemp++;
          }
          if (pref.luminosidadePreferida >= 0 &&
              pref.luminosidadePreferida <= 100) {
            somaLum += pref.luminosidadePreferida;
            countLum++;
          }

          funcionariosPresentes.add({
            'nome': pref.nomeCompleto,
            'tag_nfc': pref.tag,
            'temp_preferida': pref.temperaturaPreferida,
            'lumi_preferida': pref.luminosidadePreferida,
          });
        } else {
          // Tag não encontrada no cache; tentar derivar do cadastro de funcionário
          var func = await funcionarioService.buscarPorTag(tag);
          if (func != null) {
            // Criar preferencia a partir do funcionário e salvar no MySQL para cache
            PreferenciaTag pref = PreferenciaTag(
              tag: tag,
              nomeCompleto: func.nomeCompleto,
              temperaturaPreferida: func.tempPreferida,
              luminosidadePreferida: func.lumiPreferida.round(),
            );
            await preferenciaTagDao.salvarPreferencia(pref);

            // contabilizar
            if (pref.temperaturaPreferida >= 16 &&
                pref.temperaturaPreferida <= 32) {
              somaTemp += pref.temperaturaPreferida;
              countTemp++;
            }
            if (pref.luminosidadePreferida >= 0 &&
                pref.luminosidadePreferida <= 100) {
              somaLum += pref.luminosidadePreferida;
              countLum++;
            }

            funcionariosPresentes.add({
              'nome': pref.nomeCompleto,
              'tag_nfc': pref.tag,
              'temp_preferida': pref.temperaturaPreferida,
              'lumi_preferida': pref.luminosidadePreferida,
            });
          } else {
            // Tag realmente desconhecida: criar preferência padrão e salvar
            PreferenciaTag pref = PreferenciaTag(
              tag: tag,
              nomeCompleto: 'Usuário $tag',
              temperaturaPreferida: 25.0,
              luminosidadePreferida: 50,
            );
            await preferenciaTagDao.salvarPreferencia(pref);
            tagsDesconhecidas.add(tag);

            // contar como padrão
            somaTemp += pref.temperaturaPreferida;
            countTemp++;
            somaLum += pref.luminosidadePreferida;
            countLum++;

            funcionariosPresentes.add({
              'nome': pref.nomeCompleto,
              'tag_nfc': pref.tag,
              'temp_preferida': pref.temperaturaPreferida,
              'lumi_preferida': pref.luminosidadePreferida,
            });
          }
        }
      }

      double temperaturaMedia = countTemp > 0 ? somaTemp / countTemp : 25.0;
      double luminosidadeMedia = countLum > 0 ? somaLum / countLum : 50.0;

      int luminosidadeUtilizada = _nivelValido(luminosidadeMedia);

      if (tagsDesconhecidas.isNotEmpty) {
        _log('⚠ Tags desconhecidas: ${tagsDesconhecidas.join(', ')}');
      }

      var preferenciasGrupo = PreferenciasGrupo(
        tagsPresentes: tags,
        temperaturaMedia: temperaturaMedia,
        luminosidadeMedia: luminosidadeMedia,
        luminosidadeUtilizada: luminosidadeUtilizada,
        funcionariosPresentes: funcionariosPresentes,
        tagsDesconhecidas: tagsDesconhecidas,
      );

      _log(
        '✓ Preferências calculadas localmente: Temp=${temperaturaMedia.toStringAsFixed(1)}°C, Lumi=${luminosidadeUtilizada}%',
      );

      // Publicar preferências do grupo no Firebase para comunicação com o ESP
      try {
        await firebaseService.salvarPreferenciasGrupo(
          preferenciasGrupo.toJson(),
        );
        _log('✓ Preferências do grupo publicadas no Firebase para o ESP');
      } catch (_) {
        _log('⚠ Falha ao publicar preferências no Firebase (não crítico)');
      }

      // IMPORTANT: Não salvamos preferências de grupo no Firebase. Firebase será usado
      // somente para comunicação (comandos/leituras). Todas preferências estão no MySQL.

      return preferenciasGrupo;
    } catch (e) {
      _log('✗ Erro ao processar preferências (MySQL): $e');
      return null;
    }
  }

  // Aplicar automação baseada em preferências
  Future<void> _aplicarAutomacao(DadosSensores dados) async {
    if (dados.tags.isEmpty) return;

    // Processar preferências primeiro (MySQL/Dart)
    PreferenciasGrupo? preferencias = await processarSolicitacaoPreferencias(
      dados.tags,
    );

    // Se por algum motivo não foi possível calcular via MySQL, usar o método
    // existente como fallback (mantém compatibilidade).
    if (preferencias == null) {
      preferencias = await funcionarioService.calcularPreferenciasGrupo(
        dados.tags,
      );
    }

    // Automação da iluminação
    if (!_modoManualIluminacao) {
      await _aplicarAutomacaoIluminacao(preferencias.luminosidadeUtilizada);
    }

    // Automação do climatizador
    if (!_modoManualClimatizador && preferencias.temperaturaMedia != null) {
      await _aplicarAutomacaoClimatizador(
        dados.temperatura,
        preferencias.temperaturaMedia!,
      );
    }
  }

  Future<void> _aplicarAutomacaoIluminacao(int luminosidadeDesejada) async {
    String novoComando = luminosidadeDesejada.toString();
    if (_comandoIluminacaoAtual != novoComando) {
      await firebaseService.enviarComandoIluminacao(novoComando);
      _comandoIluminacaoAtual = novoComando;
      _log('🔆 Automação iluminação: $luminosidadeDesejada%');
    }
  }

  Future<void> _aplicarAutomacaoClimatizador(
    double temperaturaAtual,
    double temperaturaDesejada,
  ) async {
    double diferenca = temperaturaAtual - temperaturaDesejada;

    // Determinar ação desejada
    String? comandoDesejado;
    if (diferenca > 2.0) {
      comandoDesejado = 'power_on';
    } else if (diferenca < -2.0) {
      comandoDesejado = 'power_off';
    }

    if (comandoDesejado == null) return;

    // Se já sabemos que o climatizador está no estado desejado, não enviar
    if (_ultimoEstadoClima != null) {
      if (comandoDesejado == 'power_on' && _ultimoEstadoClima!.ligado) return;
      if (comandoDesejado == 'power_off' && !_ultimoEstadoClima!.ligado) return;
    }

    // Evitar reenvios rápidos: cooldown
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (_ultimoComandoClimatizador == comandoDesejado &&
        (now - _tsUltimoComandoClimatizador) < _cooldownComandoClimatizadorMs) {
      _log(
        '⏳ Ignorando reenvio de comando climatizador ($comandoDesejado) — cooldown',
      );
      return;
    }

    // Enviar comando
    bool sucesso = await firebaseService.enviarComandoClimatizador(
      comandoDesejado,
    );
    if (sucesso) {
      _ultimoComandoClimatizador = comandoDesejado;
      _tsUltimoComandoClimatizador = now;
      if (comandoDesejado == 'power_on') {
        _log(
          '❄️ Automação clima: ligando (${temperaturaAtual.toStringAsFixed(1)}°C → ${temperaturaDesejada.toStringAsFixed(1)}°C)',
        );
      } else {
        _log(
          '🔥 Automação clima: desligando (${temperaturaAtual.toStringAsFixed(1)}°C → ${temperaturaDesejada.toStringAsFixed(1)}°C)',
        );
      }
    } else {
      _log('✗ Falha ao enviar comando climatizador: $comandoDesejado');
    }
  }

  // Controles manuais - Iluminação
  Future<bool> definirIluminacaoManual(dynamic nivel) async {
    if (nivel == 'auto') {
      _modoManualIluminacao = false;
      _comandoIluminacaoAtual = 'auto';
      await firebaseService.enviarComandoIluminacao('auto');
      print('🔄 Iluminação voltou ao modo automático');
      return true;
    }

    int? nivelInt = int.tryParse(nivel.toString());
    if (nivelInt != null && [0, 25, 50, 75, 100].contains(nivelInt)) {
      _modoManualIluminacao = true;
      _comandoIluminacaoAtual = nivel.toString();
      await firebaseService.enviarComandoIluminacao(nivel);
      _log('🔆 Iluminação manual: $nivel%');
      return true;
    }

    print('✗ Nível de iluminação inválido: $nivel');
    return false;
  }

  // Controles manuais - Climatizador
  Future<bool> enviarComandoClimatizador(String comando) async {
    if (comando == 'auto') {
      _modoManualClimatizador = false;
      print('🔄 Climatizador voltou ao modo automático');
      return true;
    }

    _modoManualClimatizador = true;
    bool sucesso = await firebaseService.enviarComandoClimatizador(comando);

    if (sucesso) {
      _log('❄️ Comando climatizador: $comando');
    }

    return sucesso;
  }

  // Obter resumo do sistema
  Map<String, dynamic> obterResumoSistema() {
    return {
      'sensores': _ultimaSensorData?.toJson(),
      'climatizador': _ultimoEstadoClima?.toJson(),
      'modo_manual_iluminacao': _modoManualIluminacao,
      'modo_manual_climatizador': _modoManualClimatizador,
      'comando_iluminacao_atual': _comandoIluminacaoAtual,
      'tags_presentes': _ultimasTags,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Background sync (silenciosa) - inicia loop que processa e salva dados
  void startBackgroundSync({Duration interval = const Duration(seconds: 3)}) {
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
  int _nivelValido(double media) {
    if (media == 0) return 0;
    const niveis = [0, 25, 50, 75, 100];

    int nivelMaisProximo = niveis[0];
    double menorDiferenca = (media - niveis[0]).abs();

    for (int i = 1; i < niveis.length; i++) {
      double diferenca = (media - niveis[i]).abs();
      if (diferenca < menorDiferenca) {
        menorDiferenca = diferenca;
        nivelMaisProximo = niveis[i];
      }
    }
    return nivelMaisProximo;
  }

  // Stream de dados em tempo real - intervalo maior para dashboard mais estável
  Stream<Map<String, dynamic>> streamDadosTempoReal() async* {
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

    print('✓ Sistema IoT inicializado com sucesso!');
  }
}
