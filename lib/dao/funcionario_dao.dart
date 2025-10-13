import '../database/database_connection.dart';
import '../models/funcionario.dart';

class FuncionarioDao {
  final DatabaseConnection db;

  FuncionarioDao(this.db);

  Future<bool> inserirFuncionario(Funcionario funcionario) async {
    try {
      final conn = db.connection;
      if (conn != null) {
        var result = await conn.query(
          '''INSERT INTO funcionarios 
         (matricula, nome, sobrenome, senha, temp_preferida, lumi_preferida, tag_nfc) 
         VALUES (?, ?, ?, ?, ?, ?, ?)''',
          [
            funcionario.matricula,
            funcionario.nome,
            funcionario.sobrenome,
            funcionario.senha,
            funcionario.tempPreferida,
            funcionario.lumiPreferida,
            funcionario.tagNfc,
          ],
        );

        if (result.affectedRows != null && result.affectedRows! > 0) {
          print(
            "✓ Funcionário ${funcionario.nomeCompleto} inserido com sucesso!",
          );
          return true;
        }
        print("✗ Inserção não afetou linhas no banco");
        return false;
      } else {
        print("✗ Conexão com o banco não está ativa!");
        return false;
      }
    } catch (e) {
      print("✗ Erro ao inserir funcionário: $e");
      return false;
    }
  }

  Future<List<Funcionario>> listarFuncionarios() async {
    List<Funcionario> funcionarios = [];
    try {
      final conn = db.connection;
      if (conn == null) {
        print("✗ Conexão com o banco não está ativa");
        return funcionarios;
      }

      var result = await conn.query(
        "SELECT id, matricula, nome, sobrenome, senha, temp_preferida, lumi_preferida, tag_nfc, createdAt, updatedAt FROM funcionarios ORDER BY nome",
      );

      for (var row in result) {
        funcionarios.add(
          Funcionario.fromMap({
            'id': row[0],
            'matricula': row[1],
            'nome': row[2],
            'sobrenome': row[3],
            'senha': row[4],
            'temp_preferida': row[5],
            'lumi_preferida': row[6],
            'tag_nfc': row[7],
            'createdAt': row[8],
            'updatedAt': row[9],
          }),
        );
      }
    } catch (e) {
      print("✗ Erro ao listar funcionários: $e");
    }
    return funcionarios;
  }

  Future<Funcionario?> buscarPorMatricula(int matricula) async {
    try {
      final conn = db.connection;
      if (conn == null) return null;

      var result = await conn.query(
        "SELECT id, matricula, nome, sobrenome, senha, temp_preferida, lumi_preferida, tag_nfc, createdAt, updatedAt FROM funcionarios WHERE matricula = ?",
        [matricula],
      );

      if (result.isNotEmpty) {
        var row = result.first;
        return Funcionario.fromMap({
          'id': row[0],
          'matricula': row[1],
          'nome': row[2],
          'sobrenome': row[3],
          'senha': row[4],
          'temp_preferida': row[5],
          'lumi_preferida': row[6],
          'tag_nfc': row[7],
          'createdAt': row[8],
          'updatedAt': row[9],
        });
      }
    } catch (e) {
      print("✗ Erro ao buscar funcionário por matrícula: $e");
    }
    return null;
  }

  Future<Funcionario?> buscarPorTag(String tagNfc) async {
    try {
      final conn = db.connection;
      if (conn == null) return null;

      var result = await conn.query(
        "SELECT id, matricula, nome, sobrenome, senha, temp_preferida, lumi_preferida, tag_nfc, createdAt, updatedAt FROM funcionarios WHERE tag_nfc = ?",
        [tagNfc],
      );

      if (result.isNotEmpty) {
        var row = result.first;
        return Funcionario.fromMap({
          'id': row[0],
          'matricula': row[1],
          'nome': row[2],
          'sobrenome': row[3],
          'senha': row[4],
          'temp_preferida': row[5],
          'lumi_preferida': row[6],
          'tag_nfc': row[7],
          'createdAt': row[8],
          'updatedAt': row[9],
        });
      }
    } catch (e) {
      print("✗ Erro ao buscar funcionário por tag: $e");
    }
    return null;
  }

  Future<List<Funcionario>> buscarPorTags(List<String> tags) async {
    List<Funcionario> funcionarios = [];
    if (tags.isEmpty) return funcionarios;

    try {
      final conn = db.connection;
      if (conn == null) return funcionarios;

      String placeholders = tags.map((_) => '?').join(',');
      var result = await conn.query(
        "SELECT id, matricula, nome, sobrenome, senha, temp_preferida, lumi_preferida, tag_nfc, createdAt, updatedAt FROM funcionarios WHERE tag_nfc IN ($placeholders)",
        tags,
      );

      for (var row in result) {
        funcionarios.add(
          Funcionario.fromMap({
            'id': row[0],
            'matricula': row[1],
            'nome': row[2],
            'sobrenome': row[3],
            'senha': row[4],
            'temp_preferida': row[5],
            'lumi_preferida': row[6],
            'tag_nfc': row[7],
            'createdAt': row[8],
            'updatedAt': row[9],
          }),
        );
      }
    } catch (e) {
      print("✗ Erro ao buscar funcionários por tags: $e");
    }
    return funcionarios;
  }

  Future<bool> atualizarPreferencias(
    int matricula,
    double tempPreferida,
    int lumiPreferida,
  ) async {
    try {
      final conn = db.connection;
      if (conn == null) return false;

      var result = await conn.query(
        "UPDATE funcionarios SET temp_preferida = ?, lumi_preferida = ? WHERE matricula = ?",
        [tempPreferida, lumiPreferida, matricula],
      );

      return result.affectedRows! > 0;
    } catch (e) {
      print("✗ Erro ao atualizar preferências: $e");
      return false;
    }
  }

  Future<bool> removerFuncionario(int matricula) async {
    try {
      final conn = db.connection;
      if (conn == null) return false;

      var result = await conn.query(
        "DELETE FROM funcionarios WHERE matricula = ?",
        [matricula],
      );

      return result.affectedRows! > 0;
    } catch (e) {
      print("✗ Erro ao remover funcionário: $e");
      return false;
    }
  }
}
