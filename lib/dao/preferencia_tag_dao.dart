import 'package:mysql1/mysql1.dart';
import '../database/database_connection.dart';
import '../models/preferencia_tag.dart';

class PreferenciaTagDao {
  final DatabaseConnection dbConnection;

  PreferenciaTagDao(this.dbConnection);

  // Buscar preferência por tag NFC
  Future<PreferenciaTag?> buscarPorTag(String tag) async {
    try {
      final connection = dbConnection.connection;
      if (connection == null) return null;

      var result = await connection.query(
        'SELECT * FROM preferencias_tags WHERE tag_nfc = ?',
        [tag],
      );

      if (result.isNotEmpty) {
        var row = result.first;
        return PreferenciaTag(
          tag: row['tag_nfc'],
          nomeCompleto: row['nome_completo'] ?? '',
          temperaturaPreferida:
              (row['temperatura_preferida'] as num?)?.toDouble() ?? 25.0,
          luminosidadePreferida: row['luminosidade_preferida'] ?? 50,
          ultimaAtualizacao: row['ultima_atualizacao'],
        );
      }
    } catch (e) {
      print('✗ Erro ao buscar preferência por tag: $e');
    }
    return null;
  }

  // Salvar ou atualizar preferência
  Future<bool> salvarPreferencia(PreferenciaTag preferencia) async {
    try {
      final connection = dbConnection.connection;
      if (connection == null) return false;

      await connection.query(
        '''
        INSERT INTO preferencias_tags 
        (tag_nfc, nome_completo, temperatura_preferida, luminosidade_preferida)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
        nome_completo = VALUES(nome_completo),
        temperatura_preferida = VALUES(temperatura_preferida),
        luminosidade_preferida = VALUES(luminosidade_preferida),
        ultima_atualizacao = CURRENT_TIMESTAMP
      ''',
        [
          preferencia.tag,
          preferencia.nomeCompleto,
          preferencia.temperaturaPreferida,
          preferencia.luminosidadePreferida,
        ],
      );

      return true;
    } catch (e) {
      print('✗ Erro ao salvar preferência: $e');
      return false;
    }
  }

  // Buscar preferências de múltiplas tags
  Future<List<PreferenciaTag>> buscarMultiplasTags(List<String> tags) async {
    List<PreferenciaTag> preferencias = [];

    if (tags.isEmpty) return preferencias;

    try {
      final connection = dbConnection.connection;
      if (connection == null) return preferencias;

      // Criar placeholders para prepared statement
      String placeholders = tags.map((_) => '?').join(',');

      var result = await connection.query(
        'SELECT * FROM preferencias_tags WHERE tag_nfc IN ($placeholders)',
        tags,
      );

      for (var row in result) {
        preferencias.add(
          PreferenciaTag(
            tag: row['tag_nfc'],
            nomeCompleto: row['nome_completo'] ?? '',
            temperaturaPreferida:
                (row['temperatura_preferida'] as num?)?.toDouble() ?? 25.0,
            luminosidadePreferida: row['luminosidade_preferida'] ?? 50,
            ultimaAtualizacao: row['ultima_atualizacao'],
          ),
        );
      }
    } catch (e) {
      print('✗ Erro ao buscar múltiplas preferências: $e');
    }

    return preferencias;
  }

  // Sincronizar preferências do Firebase para MySQL (cache local)
  Future<bool> sincronizarComFirebase(
    List<PreferenciaTag> preferenciasFirebase,
  ) async {
    try {
      final connection = dbConnection.connection;
      if (connection == null) return false;

      // Usar transação para garantir consistência
      await connection.transaction((conn) async {
        for (var pref in preferenciasFirebase) {
          await conn.query(
            '''
            INSERT INTO preferencias_tags 
            (tag_nfc, nome_completo, temperatura_preferida, luminosidade_preferida)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
            nome_completo = VALUES(nome_completo),
            temperatura_preferida = VALUES(temperatura_preferida),
            luminosidade_preferida = VALUES(luminosidade_preferida),
            ultima_atualizacao = CURRENT_TIMESTAMP
          ''',
            [
              pref.tag,
              pref.nomeCompleto,
              pref.temperaturaPreferida,
              pref.luminosidadePreferida,
            ],
          );
        }
      });

      return true;
    } catch (e) {
      print('✗ Erro na sincronização com Firebase: $e');
      return false;
    }
  }

  // Listar todas as preferências
  Future<List<PreferenciaTag>> listarTodas() async {
    List<PreferenciaTag> preferencias = [];

    try {
      final connection = dbConnection.connection;
      if (connection == null) return preferencias;

      var result = await connection.query(
        'SELECT * FROM preferencias_tags ORDER BY ultima_atualizacao DESC',
      );

      for (var row in result) {
        preferencias.add(
          PreferenciaTag(
            tag: row['tag_nfc'],
            nomeCompleto: row['nome_completo'] ?? '',
            temperaturaPreferida:
                (row['temperatura_preferida'] as num?)?.toDouble() ?? 25.0,
            luminosidadePreferida: row['luminosidade_preferida'] ?? 50,
            ultimaAtualizacao: row['ultima_atualizacao'],
          ),
        );
      }
    } catch (e) {
      print('✗ Erro ao listar preferências: $e');
    }

    return preferencias;
  }
}
