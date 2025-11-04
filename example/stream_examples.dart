import 'package:pi_mds/services/firebase_service.dart';
import 'package:pi_mds/services/funcionario_service.dart';
import 'package:pi_mds/services/log_service.dart';
import 'package:pi_mds/services/saida_service.dart';
import 'package:pi_mds/controllers/sistema_iot_controller.dart';
import 'package:pi_mds/dao/historico_dao.dart';
import 'package:pi_mds/dao/funcionario_dao.dart';
import 'package:pi_mds/dao/log_dao.dart';
import 'package:pi_mds/database/database_connection.dart';
import 'package:pi_mds/config/database_config.dart';
import 'dart:async';

/// Exemplo de uso dos Streams do Firebase
/// 
/// Este exemplo demonstra como usar os novos recursos de streaming
/// para monitorar o sistema IoT em tempo real.

Future<void> main() async {
  print('🚀 Iniciando exemplo de Streams do Firebase...\n');

  // Configurar serviços
  final dbConfig = DatabaseConfig(
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: '',
    dbName: 'pi_iot_system',
  );
  final dbConnection = DatabaseConnection(dbConfig);
  await dbConnection.connect();

  final funcionarioDao = FuncionarioDao(dbConnection);
  final logDao = LogDao(dbConnection);
  final historicoDao = HistoricoDao(dbConnection);
  final saidaService = SaidaService();

  final firebaseService = FirebaseService(saidaService: saidaService);
  final funcionarioService = FuncionarioService(funcionarioDao);
  final logService = LogService(logDao, funcionarioService);

  final controller = SistemaIotController(
    firebaseService: firebaseService,
    funcionarioService: funcionarioService,
    logService: logService,
    historicoDao: historicoDao,
  );

  // ==========================================
  // EXEMPLO 1: Monitorar Sensores
  // ==========================================
  print('📊 EXEMPLO 1: Monitorando sensores em tempo real...\n');

  StreamSubscription? sensoresSubscription;
  sensoresSubscription = firebaseService.streamSensores.listen(
    (dados) {
      if (dados != null && dados.dadosValidos) {
        print('🌡️  Temperatura: ${dados.temperatura.toStringAsFixed(1)}°C');
        print('💧 Umidade: ${dados.humidade.toStringAsFixed(0)}%');
        print('💡 Luminosidade: ${dados.luminosidade}%');
        print('👥 Pessoas: ${dados.pessoas}');
        if (dados.tags.isNotEmpty) {
          print('🏷️  Tags: ${dados.tags.join(", ")}');
        }
        print('---');
      }
    },
    onError: (e) => print('❌ Erro no stream de sensores: $e'),
  );

  // Aguardar 30 segundos
  await Future.delayed(Duration(seconds: 30));
  await sensoresSubscription.cancel();
  print('✅ Stream de sensores encerrado.\n');

  // ==========================================
  // EXEMPLO 2: Monitorar Climatizador
  // ==========================================
  print('❄️  EXEMPLO 2: Monitorando climatizador em tempo real...\n');

  StreamSubscription? climaSubscription;
  climaSubscription = firebaseService.streamClimatizador.listen(
    (estado) {
      if (estado != null) {
        print('⚡ Estado: ${estado.ligado ? "LIGADO" : "DESLIGADO"}');
        if (estado.ligado) {
          print('   Velocidade: ${estado.velocidade}');
          print('   Umidificando: ${estado.umidificando ? "SIM" : "NÃO"}');
          print('   Aleta V: ${estado.aletaVertical ? "ATIVA" : "INATIVA"}');
          print('   Aleta H: ${estado.aletaHorizontal ? "ATIVA" : "INATIVA"}');
          if (estado.timer > 0) {
            print('   Timer: ${estado.timer}h');
          }
        }
        print('---');
      }
    },
    onError: (e) => print('❌ Erro no stream do climatizador: $e'),
  );

  await Future.delayed(Duration(seconds: 30));
  await climaSubscription.cancel();
  print('✅ Stream do climatizador encerrado.\n');

  // ==========================================
  // EXEMPLO 3: Monitoramento Completo com Controller
  // ==========================================
  print('🎛️  EXEMPLO 3: Monitoramento completo do sistema...\n');

  // Inicializar o controller
  await controller.inicializar();

  // Iniciar monitoramento automático com streams
  controller.startBackgroundSync();
  print('✅ Background sync iniciado com Streams!\n');

  // Monitorar mudanças por 1 minuto
  final timer = Timer.periodic(Duration(seconds: 10), (t) {
    final resumo = controller.obterResumoSistema();
    print('\n📋 Resumo do Sistema:');
    print('   Timestamp: ${resumo['timestamp']}');
    print('   Tags presentes: ${resumo['tags_presentes']}');
    print('   Comando iluminação: ${resumo['comando_iluminacao_atual']}');
    print('');
  });

  await Future.delayed(Duration(minutes: 1));
  timer.cancel();

  // Parar monitoramento
  controller.stopBackgroundSync();
  print('\n✅ Background sync encerrado.\n');

  // ==========================================
  // EXEMPLO 4: Stream Personalizado de Dados Completos
  // ==========================================
  print('📡 EXEMPLO 4: Stream de dados completos...\n');

  StreamSubscription? dadosSubscription;
  dadosSubscription = controller.streamDadosTempoReal().listen(
    (resumo) {
      print('📦 Atualização do sistema:');
      final sensores = resumo['sensores'];
      if (sensores != null) {
        print('   Temp: ${sensores['temperatura']}°C | Pessoas: ${sensores['pessoas']}');
      }
    },
    onError: (e) => print('❌ Erro: $e'),
  );

  await Future.delayed(Duration(seconds: 30));
  await dadosSubscription.cancel();
  print('✅ Stream de dados completos encerrado.\n');

  // ==========================================
  // EXEMPLO 5: Enviar Comandos e Observar Resultado
  // ==========================================
  print('🎮 EXEMPLO 5: Enviando comandos e observando resultado...\n');

  // Inscrever-se no stream antes de enviar comando
  final climaStream = firebaseService.streamClimatizador.listen(
    (estado) {
      if (estado != null) {
        print('   ↪️ Climatizador agora: ${estado.ligado ? "LIGADO" : "DESLIGADO"}');
        if (estado.ligado) {
          print('      Velocidade: ${estado.velocidade}');
        }
      }
    },
  );

  // Enviar comando para ligar climatizador
  print('📤 Enviando comando: ligar climatizador...');
  await controller.enviarComandoClimatizador('power_on', velocidade: 2);

  // Aguardar resposta
  await Future.delayed(Duration(seconds: 5));

  // Enviar comando para ajustar velocidade
  print('📤 Enviando comando: ajustar velocidade...');
  await controller.enviarComandoClimatizador('velocidade', velocidade: 3);

  await Future.delayed(Duration(seconds: 5));

  // Desligar
  print('📤 Enviando comando: desligar climatizador...');
  await controller.enviarComandoClimatizador('power_off');

  await Future.delayed(Duration(seconds: 5));
  await climaStream.cancel();
  print('✅ Teste de comandos concluído.\n');

  // ==========================================
  // EXEMPLO 6: Monitorar Última Tag RFID
  // ==========================================
  print('🏷️  EXEMPLO 6: Monitorando última tag RFID...\n');

  final tagStream = firebaseService.streamUltimaTag.listen(
    (tag) {
      if (tag != null && tag.isNotEmpty) {
        print('🆔 Nova tag detectada: $tag');
        // Limpar para não processar novamente
        firebaseService.limparUltimaTag();
      }
    },
    onError: (e) => print('❌ Erro no stream de tags: $e'),
  );

  print('   Aguardando leitura de tags... (aproxime um cartão)');
  await Future.delayed(Duration(seconds: 30));
  await tagStream.cancel();
  print('✅ Monitoramento de tags encerrado.\n');

  // ==========================================
  // EXEMPLO 7: Monitorar Solicitações de Preferências
  // ==========================================
  print('⚙️  EXEMPLO 7: Monitorando solicitações de preferências...\n');

  final prefsStream = firebaseService.streamPreferenciasRequest.listen(
    (request) async {
      if (request != null && request.isNotEmpty) {
        print('📨 Solicitação de preferências recebida!');
        // O controller já processa automaticamente, mas podemos fazer algo adicional
        print('   Processando...');
      }
    },
    onError: (e) => print('❌ Erro: $e'),
  );

  await Future.delayed(Duration(seconds: 30));
  await prefsStream.cancel();
  print('✅ Monitoramento de preferências encerrado.\n');

  // ==========================================
  // Limpeza e Encerramento
  // ==========================================
  print('🧹 Limpando recursos...');

  // Parar todos os streams
  firebaseService.stopAllStreams();

  // Dispose do controller e serviços
  controller.dispose();

  // Fechar conexão com banco
  await dbConnection.close();

  print('✅ Todos os recursos liberados.\n');
  print('👋 Exemplo finalizado com sucesso!');
}

// ==========================================
// EXEMPLO 8: Uso Básico Simplificado
// ==========================================

/// Exemplo mais simples para casos de uso básicos
Future<void> exemploSimples() async {
  final firebaseService = FirebaseService();

  // Apenas ouvir atualizações de sensores
  firebaseService.streamSensores.listen((dados) {
    if (dados != null) {
      print('Temp: ${dados.temperatura}°C');
    }
  });

  // Aguardar indefinidamente (ou até Ctrl+C)
  await Future.delayed(Duration(hours: 1));

  // Limpar quando terminar
  firebaseService.dispose();
}

// ==========================================
// EXEMPLO 9: Tratamento de Erros Avançado
// ==========================================

Future<void> exemploComTratamentoDeErros() async {
  final firebaseService = FirebaseService();

  // Stream com tratamento robusto de erros
  firebaseService.streamSensores.listen(
    (dados) {
      // Sucesso
      if (dados != null && dados.dadosValidos) {
        print('✅ Dados válidos: ${dados.temperatura}°C');
      } else {
        print('⚠️  Dados inválidos ou nulos');
      }
    },
    onError: (error, stackTrace) {
      // Erro
      print('❌ Erro capturado: $error');
      print('Stack trace: $stackTrace');
      
      // Tentar reconectar ou notificar usuário
    },
    onDone: () {
      // Stream encerrado
      print('ℹ️  Stream de sensores foi encerrado');
    },
    cancelOnError: false, // Continuar mesmo com erros
  );

  await Future.delayed(Duration(minutes: 1));
  firebaseService.dispose();
}
