import 'package:mysql1/mysql1.dart';
import '../config/database_config.dart';

class DatabaseConnection {
  final DatabaseConfig config;
  MySqlConnection? _connection;

  DatabaseConnection(this.config);

  Future<bool> connect() async {
    try {
      _connection = await MySqlConnection.connect(
        ConnectionSettings(
          host: config.host,
          port: config.port,
          user: config.user,
          password: config.password,
          db: config.dbName,
        ),
      );

      try {
        await _connection!.query('SELECT 1');
        print("✓ Conexão MySQL estabelecida com sucesso!");
        return true;
      } catch (queryError) {
        print("✗ Erro ao executar query de teste: $queryError");
        return false;
      }
    } catch (e) {
      print("✗ Falha na conexão MySQL: $e");
      return false;
    }
  }

  Future<void> close() async {
    await _connection?.close();
    print("✓ Conexão MySQL encerrada!");
  }

  MySqlConnection? get connection => _connection;

  Future<void> createTables() async {
    if (_connection == null) return;

    try {
      await _connection!.query('''
        CREATE TABLE IF NOT EXISTS funcionarios (
          id INT AUTO_INCREMENT PRIMARY KEY,
          matricula INT UNIQUE NOT NULL,
          nome VARCHAR(100) NOT NULL,
          sobrenome VARCHAR(100) NOT NULL,
          senha VARCHAR(100) NOT NULL,
          temp_preferida FLOAT DEFAULT 24.0,
          lumi_preferida INT DEFAULT 75,
          tag_nfc VARCHAR(50) UNIQUE,
          createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
      ''');

      await _connection!.query('''
        CREATE TABLE IF NOT EXISTS logs (
          id INT AUTO_INCREMENT PRIMARY KEY,
          funcionario_id INT,
          matricula VARCHAR(20),
          nome_completo VARCHAR(150),
          tipo ENUM('entrada', 'saida') NOT NULL,
          tag_nfc VARCHAR(50),
          hash_controle VARCHAR(64),
          createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX idx_funcionario_id (funcionario_id),
          INDEX idx_matricula (matricula),
          INDEX idx_createdAt (createdAt)
        )
      ''');

      try {
        await _connection!.query(
          "ALTER TABLE logs ADD COLUMN IF NOT EXISTS hash_controle VARCHAR(64)",
        );
      } catch (e) {
        try {
          await _connection!.query(
            "ALTER TABLE logs ADD COLUMN hash_controle VARCHAR(64)",
          );
        } catch (_) {
        }
      }

      try {
        await _connection!.query(
          "ALTER TABLE logs ADD UNIQUE INDEX idx_hash_controle (hash_controle)",
        );
      } catch (_) {
      }

      await _connection!.query('''
        CREATE TABLE IF NOT EXISTS dados_historicos (
          id INT AUTO_INCREMENT PRIMARY KEY,
          temperatura FLOAT,
          humidade FLOAT,
          ldr INT,
          iluminacao_artificial INT DEFAULT 0,
          pessoas INT DEFAULT 0,
          tags_presentes JSON,
          clima_ligado BOOLEAN DEFAULT FALSE,
          clima_umidificando BOOLEAN DEFAULT FALSE,
          clima_velocidade INT DEFAULT 0,
          timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      print("✓ Tabelas criadas/verificadas com sucesso!");
    } catch (e) {
      print("✗ Erro ao criar tabelas: $e");
    }
  }
}
