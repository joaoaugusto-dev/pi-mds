import '../database/database_connection.dart';
import '../models/dados_sensores.dart';

class HistoricoDao {
  final DatabaseConnection db;

  HistoricoDao(this.db);

  Future<void> salvarDadosHistoricos(
    DadosSensores dados, {
    bool? climaLigado,
    bool? climaUmidificando,
    int? climaVelocidade,
    bool? modoManualIlum,
    bool? modoManualClima,
    int? intensidadeLuzes,
  }) async {
    try {
      final conn = db.connection;
      if (conn != null) {
        await conn.query(
          '''INSERT INTO dados_historicos 
             (temperatura, humidade, luminosidade, ldr, intensidade_luzes, pessoas, tags_presentes, 
              clima_ligado, clima_umidificando, clima_velocidade, 
              modo_manual_ilum, modo_manual_clima) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            dados.temperatura,
            dados.humidade,
            dados.luminosidade,
            dados.ldr,
            intensidadeLuzes ?? dados.luminosidade,
            dados.pessoas,
            dados.tags.isEmpty
                ? '[]'
                : '[${dados.tags.map((tag) => '"$tag"').join(',')}]',
            climaLigado ?? false,
            climaUmidificando ?? false,
            climaVelocidade ?? 0,
            modoManualIlum ?? false,
            modoManualClima ?? false,
          ],
        );
        // Mensagem de sucesso removida para evitar poluição do console em modo background
      }
    } catch (e) {
      print("✗ Erro ao salvar dados históricos: $e");
    }
  }

  Future<List<Map<String, dynamic>>> buscarHistorico({
    DateTime? inicio,
    DateTime? fim,
    int limit = 1000,
  }) async {
    List<Map<String, dynamic>> historico = [];
    try {
      final conn = db.connection;
      if (conn == null) return historico;

      String query = '''
        SELECT id, temperatura, humidade, luminosidade, ldr, intensidade_luzes, pessoas, tags_presentes,
               clima_ligado, clima_umidificando, clima_velocidade,
               modo_manual_ilum, modo_manual_clima, timestamp
        FROM dados_historicos
      ''';

      List<dynamic> params = [];

      if (inicio != null && fim != null) {
        query += ' WHERE timestamp BETWEEN ? AND ?';
        params.addAll([inicio.toIso8601String(), fim.toIso8601String()]);
      }

      query += ' ORDER BY timestamp DESC LIMIT ?';
      params.add(limit);

      var result = await conn.query(query, params);

      for (var row in result) {
        historico.add({
          'id': row[0],
          'temperatura': row[1],
          'humidade': row[2],
          'luminosidade': row[3],
          'ldr': row[4],
          'intensidade_luzes': row[5],
          'pessoas': row[6],
          'tags_presentes': row[7],
          'clima_ligado': row[8],
          'clima_umidificando': row[9],
          'clima_velocidade': row[10],
          'modo_manual_ilum': row[11],
          'modo_manual_clima': row[12],
          'timestamp': row[13],
        });
      }
    } catch (e) {
      print("✗ Erro ao buscar histórico: $e");
    }
    return historico;
  }

  Future<Map<String, double>> calcularMediasHistoricas({
    DateTime? inicio,
    DateTime? fim,
  }) async {
    Map<String, double> medias = {
      'temperatura': 0.0,
      'humidade': 0.0,
      'luminosidade': 0.0,
      'ldr': 0.0,
      'intensidade_luzes': 0.0,
      'pessoas': 0.0,
    };

    try {
      final conn = db.connection;
      if (conn == null) return medias;

      String query = '''
        SELECT AVG(temperatura) as temp_media, 
               AVG(humidade) as hum_media,
               AVG(luminosidade) as lumi_media,
               AVG(ldr) as ldr_media,
               AVG(intensidade_luzes) as intensidade_media,
               AVG(pessoas) as pessoas_media
        FROM dados_historicos
      ''';

      List<dynamic> params = [];

      if (inicio != null && fim != null) {
        query += ' WHERE timestamp BETWEEN ? AND ?';
        params.addAll([inicio.toIso8601String(), fim.toIso8601String()]);
      }

      var result = await conn.query(query, params);

      if (result.isNotEmpty) {
        var row = result.first;
        medias['temperatura'] = (row[0] as num?)?.toDouble() ?? 0.0;
        medias['humidade'] = (row[1] as num?)?.toDouble() ?? 0.0;
        medias['luminosidade'] = (row[2] as num?)?.toDouble() ?? 0.0;
        medias['ldr'] = (row[3] as num?)?.toDouble() ?? 0.0;
        medias['intensidade_luzes'] = (row[4] as num?)?.toDouble() ?? 0.0;
        medias['pessoas'] = (row[5] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      print("✗ Erro ao calcular médias históricas: $e");
    }
    return medias;
  }

  Future<int> contarRegistros({DateTime? inicio, DateTime? fim}) async {
    try {
      final conn = db.connection;
      if (conn == null) return 0;

      String query = 'SELECT COUNT(*) FROM dados_historicos';
      List<dynamic> params = [];

      if (inicio != null && fim != null) {
        query += ' WHERE timestamp BETWEEN ? AND ?';
        params.addAll([inicio.toIso8601String(), fim.toIso8601String()]);
      }

      var result = await conn.query(query, params);
      return result.first[0] ?? 0;
    } catch (e) {
      print("✗ Erro ao contar registros: $e");
      return 0;
    }
  }
}
