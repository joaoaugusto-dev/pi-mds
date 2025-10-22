import '../dao/funcionario_dao.dart';
import '../models/funcionario.dart';
import '../models/preferencias_grupo.dart';
import 'saida_service.dart';

class FuncionarioService {
  final FuncionarioDao funcionarioDao;
  final SaidaService? saidaService;

  FuncionarioService(
    this.funcionarioDao, {
    this.saidaService,
  });

  // Calcular preferências do grupo com base nas tags presentes
  Future<PreferenciasGrupo>
  calcularPreferenciasGrupo(
    List<String> tags,
  ) async {
    if (tags.isEmpty) {
      return PreferenciasGrupo(
        tagsPresentes: tags,
        temperaturaMedia: 25.0,
        luminosidadeMedia: 50.0,
        luminosidadeUtilizada: 50,
        funcionariosPresentes: [],
        tagsDesconhecidas: [],
      );
    }

    // Buscar funcionários cadastrados com essas tags
    List<Funcionario> funcionarios =
        await funcionarioDao.buscarPorTags(tags);

    // Separar tags conhecidas e desconhecidas
    List<String> tagsConhecidas = funcionarios
        .map((f) => f.tagNfc!)
        .toList();
    List<String> tagsDesconhecidas = tags
        .where(
          (tag) => !tagsConhecidas.contains(tag),
        )
        .toList();

    // Preparar lista de funcionários presentes
    List<Map<String, dynamic>>
    funcionariosPresentes = funcionarios
        .map(
          (f) => {
            'nome': f.nomeCompleto,
            'matricula': f.matricula,
            'temp_preferida': f.tempPreferida,
            'lumi_preferida': f.lumiPreferida,
            'tag_nfc': f.tagNfc,
          },
        )
        .toList();

    // Calcular médias apenas com funcionários válidos
    double? temperaturaMedia;
    double? luminosidadeMedia;
    int luminosidadeUtilizada = 50;

    if (funcionarios.isNotEmpty) {
      // Filtrar funcionários com preferências válidas para temperatura (16-32°C)
      List<Funcionario>
      funcionariosTemperaturaValida = funcionarios
          .where(
            (f) =>
                f.tempPreferida >= 16 &&
                f.tempPreferida <= 32,
          )
          .toList();

      // Filtrar funcionários com preferências válidas para luminosidade (0-100%)
      List<Funcionario>
      funcionariosLuminosidadeValida =
          funcionarios
              .where(
                (f) =>
                    f.lumiPreferida >= 0 &&
                    f.lumiPreferida <= 100,
              )
              .toList();

      // Calcular temperatura média
      if (funcionariosTemperaturaValida
          .isNotEmpty) {
        double somaTemp =
            funcionariosTemperaturaValida.fold(
              0.0,
              (sum, f) => sum + f.tempPreferida,
            );
        temperaturaMedia =
            somaTemp /
            funcionariosTemperaturaValida.length;
      } else {
        temperaturaMedia = 25.0; // Padrão
      }

      // Calcular luminosidade média
      if (funcionariosLuminosidadeValida
          .isNotEmpty) {
        double somaLumi =
            funcionariosLuminosidadeValida.fold(
              0.0,
              (sum, f) => sum + f.lumiPreferida,
            );
        luminosidadeMedia =
            somaLumi /
            funcionariosLuminosidadeValida.length;
        luminosidadeUtilizada = _nivelValido(
          luminosidadeMedia,
        );
      } else {
        luminosidadeMedia = 50.0; // Padrão
        luminosidadeUtilizada = 50;
      }

      final linha1 =
          '✓ Preferências calculadas para ${funcionarios.length} funcionários:';
      final linha2 =
          '  -> Temp: ${funcionariosTemperaturaValida.length} valores válidos, média: ${temperaturaMedia.toStringAsFixed(1)}°C';
      final linha3 =
          '  -> Lumi: ${funcionariosLuminosidadeValida.length} valores válidos, média: ${luminosidadeMedia.toStringAsFixed(1)}% (utilizada: $luminosidadeUtilizada%)';

      if (saidaService != null) {
        saidaService!.adicionar(linha1);
        saidaService!.adicionar(linha2);
        saidaService!.adicionar(linha3);
      } else {
        print(linha1);
        print(linha2);
        print(linha3);
      }
    } else {
      temperaturaMedia = 25.0;
      luminosidadeMedia = 50.0;
      luminosidadeUtilizada = 50;
      final aviso =
          '⚠ Nenhum funcionário cadastrado. Usando valores padrão.';
      if (saidaService != null) {
        saidaService!.adicionar(aviso);
      } else {
        print(aviso);
      }
    }

    if (tagsDesconhecidas.isNotEmpty) {
      final msg =
          '❌ Tags desconhecidas ignoradas: ${tagsDesconhecidas.join(', ')}';
      if (saidaService != null) {
        saidaService!.adicionar(msg);
      } else {
        print(msg);
      }
    }

    return PreferenciasGrupo(
      tagsPresentes: tags,
      temperaturaMedia: temperaturaMedia,
      luminosidadeMedia: luminosidadeMedia,
      luminosidadeUtilizada:
          luminosidadeUtilizada,
      funcionariosPresentes:
          funcionariosPresentes,
      tagsDesconhecidas: tagsDesconhecidas,
    );
  }

  // Função auxiliar para "snapping" de luminosidade para múltiplos de 25
  int _nivelValido(double media) {
    if (media == 0) return 0;
    const niveis = [0, 25, 50, 75, 100];

    int nivelMaisProximo = niveis[0];
    double menorDiferenca = (media - niveis[0])
        .abs();

    for (int i = 1; i < niveis.length; i++) {
      double diferenca = (media - niveis[i])
          .abs();
      if (diferenca < menorDiferenca) {
        menorDiferenca = diferenca;
        nivelMaisProximo = niveis[i];
      }
    }
    return nivelMaisProximo;
  }

  // Listar todos os funcionários
  Future<List<Funcionario>> listarTodos() async {
    return await funcionarioDao
        .listarFuncionarios();
  }

  // Buscar funcionário por matrícula
  Future<Funcionario?> buscarPorMatricula(
    int matricula,
  ) async {
    return await funcionarioDao
        .buscarPorMatricula(matricula);
  }

  // Buscar funcionário por tag NFC
  Future<Funcionario?> buscarPorTag(
    String tag,
  ) async {
    return await funcionarioDao.buscarPorTag(tag);
  }

  // Cadastrar novo funcionário
  Future<bool> cadastrar(
    Funcionario funcionario,
  ) async {
    try {
      return await funcionarioDao
          .inserirFuncionario(funcionario);
    } catch (e) {
      print(
        '✗ Erro ao cadastrar funcionário: $e',
      );
      return false;
    }
  }

  // Atualizar preferências
  Future<bool> atualizarPreferencias(
    int matricula,
    double temperatura,
    int luminosidade,
  ) async {
    // Validações
    if (temperatura < 16 || temperatura > 32) {
      print(
        '✗ Temperatura deve estar entre 16°C e 32°C',
      );
      return false;
    }

    if (![
      0,
      25,
      50,
      75,
      100,
    ].contains(luminosidade)) {
      print(
        '✗ Luminosidade deve ser 0, 25, 50, 75 ou 100%',
      );
      return false;
    }

    return await funcionarioDao
        .atualizarPreferencias(
          matricula,
          temperatura,
          luminosidade,
        );
  }

  // Remover funcionário
  Future<bool> remover(int matricula) async {
    return await funcionarioDao
        .removerFuncionario(matricula);
  }

  // Métodos adicionais para interface
  Future<bool> salvar(
    Funcionario funcionario,
  ) async {
    try {
      return await funcionarioDao
          .inserirFuncionario(funcionario);
    } catch (e) {
      print('✗ Erro ao salvar funcionário: $e');
      return false;
    }
  }

  Future<bool> atualizar(
    Funcionario funcionario,
  ) async {
    try {
      return await funcionarioDao
          .atualizarPreferencias(
            funcionario.matricula,
            funcionario.tempPreferida,
            funcionario.lumiPreferida,
          );
    } catch (e) {
      print(
        '✗ Erro ao atualizar funcionário: $e',
      );
      return false;
    }
  }

  Future<bool> excluir(int matricula) async {
    try {
      return await funcionarioDao
          .removerFuncionario(matricula);
    } catch (e) {
      print('✗ Erro ao excluir funcionário: $e');
      return false;
    }
  }

  Future<Funcionario?> buscarPorMatriculaUnica(
    int matricula,
  ) async {
    try {
      return await funcionarioDao
          .buscarPorMatricula(matricula);
    } catch (e) {
      print('✗ Erro ao buscar funcionário: $e');
      return null;
    }
  }
}
