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

      // Testar a conexão
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

  // Criar tabelas se não existirem
  Future<void> createTables() async {
    if (_connection == null) return;

    try {
      // Tabela de funcionários
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

      // Tabela de logs
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

      // Garantir que a coluna hash_controle exista em bases antigas (migração silenciosa)
      try {
        // Usamos ADD COLUMN IF NOT EXISTS quando disponível (MySQL 8+).
        await _connection!.query(
          "ALTER TABLE logs ADD COLUMN IF NOT EXISTS hash_controle VARCHAR(64)",
        );
      } catch (e) {
        // Alguns servidores MySQL mais antigos não suportam IF NOT EXISTS; tentar adicionar e ignorar erro se já existir
        try {
          await _connection!.query(
            "ALTER TABLE logs ADD COLUMN hash_controle VARCHAR(64)",
          );
        } catch (_) {
          // ignorar
        }
      }

      // Criar índice único para evitar duplicatas pelo hash de controle (se não existir)
      try {
        await _connection!.query(
          "ALTER TABLE logs ADD UNIQUE INDEX idx_hash_controle (hash_controle)",
        );
      } catch (_) {
        // ignorar erros (índice já existe ou não pode ser criado)
      }

      // Tabela de dados históricos dos sensores (para Power BI)
      // Adicionamos colunas ldr (valor bruto do sensor) e intensidade_luzes
      // (nível percentual das luzes ligadas) separadas da leitura de
      // luminosidade ambiente.
      await _connection!.query('''
        CREATE TABLE IF NOT EXISTS dados_historicos (
          id INT AUTO_INCREMENT PRIMARY KEY,
          temperatura FLOAT,
          humidade FLOAT,
          luminosidade INT,
          ldr INT,
          intensidade_luzes INT,
          pessoas INT DEFAULT 0,
          tags_presentes JSON,
          clima_ligado BOOLEAN DEFAULT FALSE,
          clima_umidificando BOOLEAN DEFAULT FALSE,
          clima_velocidade INT DEFAULT 0,
          modo_manual_ilum BOOLEAN DEFAULT FALSE,
          modo_manual_clima BOOLEAN DEFAULT FALSE,
          timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Migração silenciosa para bases antigas: garantir colunas ldr e intensidade_luzes
      try {
        await _connection!.query(
          "ALTER TABLE dados_historicos ADD COLUMN IF NOT EXISTS ldr INT",
        );
      } catch (_) {
        try {
          await _connection!.query(
            "ALTER TABLE dados_historicos ADD COLUMN ldr INT",
          );
        } catch (_) {}
      }

      try {
        await _connection!.query(
          "ALTER TABLE dados_historicos ADD COLUMN IF NOT EXISTS intensidade_luzes INT",
        );
      } catch (_) {
        try {
          await _connection!.query(
            "ALTER TABLE dados_historicos ADD COLUMN intensidade_luzes INT",
          );
        } catch (_) {}
      }

      // Tabela de preferências por tag NFC (cache local para performance)
      await _connection!.query('''
        CREATE TABLE IF NOT EXISTS preferencias_tags (
          id INT AUTO_INCREMENT PRIMARY KEY,
          tag_nfc VARCHAR(50) UNIQUE NOT NULL,
          nome_completo VARCHAR(150),
          temperatura_preferida FLOAT DEFAULT 25.0,
          luminosidade_preferida INT DEFAULT 50,
          ultima_atualizacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX idx_tag_nfc (tag_nfc)
        )
      ''');

      print("✓ Tabelas criadas/verificadas com sucesso!");
    } catch (e) {
      print("✗ Erro ao criar tabelas: $e");
    }
  }
}
