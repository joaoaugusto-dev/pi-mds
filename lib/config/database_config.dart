class DatabaseConfig {
  final String host;
  final int port;
  final String user;
  final String? password;
  final String dbName;

  DatabaseConfig({
    required this.host,
    required this.port,
    required this.user,
    this.password,
    required this.dbName,
  });

  // Configuração padrão para o projeto
  static DatabaseConfig get defaultConfig => DatabaseConfig(
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: null, // ou sua senha do MySQL
    dbName: 'pi_iot_system',
  );
}
