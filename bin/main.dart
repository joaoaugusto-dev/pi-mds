import 'package:pi_mds/config/database_config.dart';
import 'package:pi_mds/database/database_connection.dart';
import 'package:pi_mds/dao/funcionario_dao.dart';
import 'package:pi_mds/dao/log_dao.dart';
import 'package:pi_mds/dao/historico_dao.dart';
import 'package:pi_mds/dao/preferencia_tag_dao.dart';
import 'package:pi_mds/services/firebase_service.dart';
import 'package:pi_mds/services/funcionario_service.dart';
import 'package:pi_mds/services/saida_service.dart';
import 'package:pi_mds/services/log_service.dart';
import 'package:pi_mds/controllers/sistema_iot_controller.dart';
import 'package:pi_mds/ui/menu_interface_simple.dart';

Future<void> main() async {
  print('🚀 Iniciando Sistema IoT Dashboard...\n');

  try {
    print('📊 Configurando conexão MySQL...');
    DatabaseConfig dbConfig = DatabaseConfig.defaultConfig;
    DatabaseConnection dbConnection = DatabaseConnection(dbConfig);

    bool conectado = await dbConnection.connect();
    if (!conectado) {
      print('❌ Falha ao conectar com MySQL. Verifique as configurações.');
      return;
    }

    print('🔧 Verificando/criando tabelas...');
    await dbConnection.createTables();

    print('📝 Inicializando DAOs...');
    FuncionarioDao funcionarioDao = FuncionarioDao(dbConnection);
    LogDao logDao = LogDao(dbConnection);
    HistoricoDao historicoDao = HistoricoDao(dbConnection);
    PreferenciaTagDao preferenciaTagDao = PreferenciaTagDao(dbConnection);

    print('🔧 Inicializando Services...');
    SaidaService saidaService = SaidaService(capacidade: 500);

    FirebaseService firebaseService = FirebaseService(
      saidaService: saidaService,
    );
    FuncionarioService funcionarioService = FuncionarioService(
      funcionarioDao,
      saidaService: saidaService,
    );
    LogService logService = LogService(logDao, funcionarioService);

    print('🎮 Inicializando Controller IoT...');
    SistemaIotController sistemaController = SistemaIotController(
      firebaseService: firebaseService,
      funcionarioService: funcionarioService,
      logService: logService,
      historicoDao: historicoDao,
      preferenciaTagDao: preferenciaTagDao,
    );

    await sistemaController.inicializar();

    print('🖥️  Iniciando interface...\n');
    await Future.delayed(Duration(seconds: 2));

    sistemaController.setVerbose(false);
    sistemaController.startBackgroundSync(interval: Duration(seconds: 3));

    MenuInterface menu = MenuInterface(
      funcionarioService: funcionarioService,
      logService: logService,
      firebaseService: firebaseService,
      sistemaController: sistemaController,
      saidaService: saidaService,
    );

    await menu.iniciar();
    sistemaController.stopBackgroundSync();
  } catch (e) {
    print('❌ Erro ao inicializar sistema: $e');
  }

  print('\n👋 Sistema finalizado.');
}
