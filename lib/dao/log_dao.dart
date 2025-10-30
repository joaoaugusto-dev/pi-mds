import '../database/database_connection.dart';
import '../models/log_entry.dart';
import '../utils/console.dart';

class LogDao {
  final DatabaseConnection db;

  LogDao(this.db);

  Future<void> inserirLog(LogEntry log) async {
    try {
      final conn = db.connection;
      if (conn != null) {
        String hashData =
            '${log.tagNfc ?? ''}_${log.tipo}_${log.nomeCompleto}_${DateTime.now().toString().substring(0, 16)}';

        try {
          await conn.query(
            '''INSERT INTO logs 
               (funcionario_id, matricula, nome_completo, tipo, tag_nfc, hash_controle) 
               VALUES (?, ?, ?, ?, ?, MD5(?))''',
            [
              log.funcionarioId,
              log.matricula,
              log.nomeCompleto,
              log.tipo,
              log.tagNfc,
              hashData,
            ],
          );
          print("✓ Log ${colorTipo(log.tipo)} registrado: ${log.nomeCompleto}");
        } catch (e) {
          var err = e.toString();
          if (err.contains("Unknown column 'hash_controle'") ||
              err.contains('1054') ||
              err.contains('42S22')) {
            try {
              await conn.query(
                '''INSERT INTO logs 
                   (funcionario_id, matricula, nome_completo, tipo, tag_nfc) 
                   VALUES (?, ?, ?, ?, ?)''',
                [
                  log.funcionarioId,
                  log.matricula,
                  log.nomeCompleto,
                  log.tipo,
                  log.tagNfc,
                ],
              );
              print(
                "✓ Log ${colorTipo(log.tipo)} registrado (fallback sem hash): ${log.nomeCompleto}",
              );
            } catch (e2) {
              if (e2.toString().contains('Duplicate entry')) {
                print(
                  "⏩ Log duplicado ignorado: ${log.tipo} - ${log.nomeCompleto} (hash collision)",
                );
              } else {
                rethrow;
              }
            }
          } else if (err.contains('Duplicate entry')) {
            print(
              "⏩ Log duplicado ignorado: ${log.tipo} - ${log.nomeCompleto} (hash collision)",
            );
          } else {
            rethrow;
          }
        }
      } else {
        print("✗ Conexão com o banco não está ativa!");
      }
    } catch (e) {
      print("✗ Erro ao inserir log: $e");
    }
  }

  Future<List<LogEntry>> listarLogs({int limit = 100}) async {
    List<LogEntry> logs = [];
    try {
      final conn = db.connection;
      if (conn == null) {
        print("✗ Conexão com o banco não está ativa");
        return logs;
      }

      var result = await conn.query(
        "SELECT id, funcionario_id, matricula, nome_completo, tipo, tag_nfc, createdAt, updatedAt FROM logs ORDER BY createdAt DESC LIMIT ?",
        [limit],
      );

      for (var row in result) {
        logs.add(
          LogEntry.fromMap({
            'id': row[0],
            'funcionario_id': row[1],
            'matricula': row[2],
            'nome_completo': row[3],
            'tipo': row[4],
            'tag_nfc': row[5],
            'createdAt': row[6],
            'updatedAt': row[7],
          }),
        );
      }
    } catch (e) {
      print("✗ Erro ao listar logs: $e");
    }
    return logs;
  }

  Future<List<LogEntry>> buscarLogsPorPeriodo(
    DateTime inicio,
    DateTime fim,
  ) async {
    List<LogEntry> logs = [];
    try {
      final conn = db.connection;
      if (conn == null) return logs;

      var result = await conn.query(
        "SELECT id, funcionario_id, matricula, nome_completo, tipo, tag_nfc, createdAt, updatedAt FROM logs WHERE createdAt BETWEEN ? AND ? ORDER BY createdAt DESC",
        [inicio.toIso8601String(), fim.toIso8601String()],
      );

      for (var row in result) {
        logs.add(
          LogEntry.fromMap({
            'id': row[0],
            'funcionario_id': row[1],
            'matricula': row[2],
            'nome_completo': row[3],
            'tipo': row[4],
            'tag_nfc': row[5],
            'createdAt': row[6],
            'updatedAt': row[7],
          }),
        );
      }
    } catch (e) {
      print("✗ Erro ao buscar logs por período: $e");
    }
    return logs;
  }

  Future<List<LogEntry>> buscarLogsPorFuncionario(int funcionarioId) async {
    List<LogEntry> logs = [];
    try {
      final conn = db.connection;
      if (conn == null) return logs;

      var result = await conn.query(
        "SELECT id, funcionario_id, matricula, nome_completo, tipo, tag_nfc, createdAt, updatedAt FROM logs WHERE funcionario_id = ? OR matricula = ? ORDER BY createdAt DESC",
        [funcionarioId, funcionarioId],
      );

      for (var row in result) {
        logs.add(
          LogEntry.fromMap({
            'id': row[0],
            'funcionario_id': row[1],
            'matricula': row[2],
            'nome_completo': row[3],
            'tipo': row[4],
            'tag_nfc': row[5],
            'createdAt': row[6],
            'updatedAt': row[7],
          }),
        );
      }
    } catch (e) {
      print("✗ Erro ao buscar logs por funcionário: $e");
    }
    return logs;
  }

  Future<Map<String, int>> estatisticasHoje() async {
    Map<String, int> stats = {'entradas': 0, 'saidas': 0};
    try {
      final conn = db.connection;
      if (conn == null) return stats;

      var hoje = DateTime.now();
      var inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);
      var fimHoje = inicioHoje.add(Duration(days: 1));

      var result = await conn.query(
        "SELECT tipo, COUNT(*) as total FROM logs WHERE createdAt BETWEEN ? AND ? GROUP BY tipo",
        [inicioHoje.toIso8601String(), fimHoje.toIso8601String()],
      );

      for (var row in result) {
        String tipo = row[0];
        int total = row[1];
        stats[tipo == 'entrada' ? 'entradas' : 'saidas'] = total;
      }
    } catch (e) {
      print("✗ Erro ao buscar estatísticas de hoje: $e");
    }
    return stats;
  }
}
