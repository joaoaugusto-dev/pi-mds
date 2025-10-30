import 'dart:io';
import 'dart:async';
import 'dart:convert';
import '../services/funcionario_service.dart';
import '../services/log_service.dart';
import '../services/firebase_service.dart';
import '../services/saida_service.dart';
import '../controllers/sistema_iot_controller.dart';
import '../models/funcionario.dart';
import '../models/log_entry.dart';
import '../utils/console.dart';
import '../models/dados_sensores.dart';
import '../models/estado_climatizador.dart';
import '../models/preferencias_grupo.dart';

class MenuInterface {
  static const int _larguraPadrao = 86;

  final FuncionarioService funcionarioService;
  final LogService logService;
  final FirebaseService firebaseService;
  final SaidaService? saidaService;
  final SistemaIotController sistemaController;
  bool _executando = true;
  bool _dashboardRodando = false;
  StreamSubscription<Map<String, dynamic>>? _dashboardSubs;
  StreamSubscription<String>? _keySubs;
  late final Stream<String> _inputLines;

  void _iniciarDashboardBackground() {
    if (_dashboardRodando) return;
    _dashboardRodando = true;
    _mostrarCabecalho();
    print('Dashboard iniciado em background. Atualizações aparecerão no console.');
    print('Pressione ENTER para sair do dashboard e voltar ao menu principal.');
    print('');

    sistemaController.setVerbose(false);

    _dashboardSubs = sistemaController.streamDadosTempoReal().listen((data) async {
      try {
        final tagsVal = data['tags_presentes'] ?? data['tags'] ?? [];
        if (tagsVal is List && tagsVal.isNotEmpty) {
          final prefs = await funcionarioService.calcularPreferenciasGrupo(
            tagsVal.map((e) => e.toString()).toList(),
          );
          final List<String> nomesPresentes = prefs.funcionariosPresentes
              .map((m) => _primeiroNome((m['nome'] ?? '').toString()))
              .where((n) => n.trim().isNotEmpty)
              .toList();

          final dataExt = Map<String, dynamic>.from(data);
          dataExt['nomes_presentes'] = nomesPresentes;
          data = dataExt;
        }
      } catch (_) {}

      print('\n' * 3);

      print(_criarLinhaBorda(inicio: true));
      final horario = DateTime.now().toString().substring(11, 19);
      print(_padInner('Dashboard IoT - $horario'));
      print(_criarLinhaBorda(meio: true));
      print(_formatResumoSistema(data));
      print(_criarLinhaBorda(meio: true));
      print(_padInner('Pressione ENTER para sair do dashboard'));
      print(_criarLinhaBorda(fim: true));
      print('');
    });

    _keySubs = _inputLines.listen((line) async {
      final t = line.trim().toLowerCase();
      if (t == '' || t == 'q') {
        await _pararDashboardBackground();
      }
    });
  }

  Future<void> _pararDashboardBackground() async {
    if (!_dashboardRodando) return;
    _dashboardSubs?.cancel();
    _dashboardSubs = null;
    await _keySubs?.cancel();
    _keySubs = null;
    _dashboardRodando = false;
    _mostrarCabecalho();
    sistemaController.setVerbose(false);
    print('📊 Dashboard em background parado.');
    await _aguardarTecla();
  }

  MenuInterface({
    required this.funcionarioService,
    required this.logService,
    required this.firebaseService,
    required this.sistemaController,
    this.saidaService,
  }) {
    _inputLines = stdin.transform(utf8.decoder).transform(const LineSplitter()).asBroadcastStream();
  }

  Future<void> iniciar() async {
    print('\n🏭 Sistema IoT Packbag - Dashboard Console');
    print('Versão 2.0 - Dart/Firebase Edition');

    while (_executando) {
      _mostrarMenuPrincipal();
      await _processarEscolhaMenu();
    }
  }

  void _mostrarMenuPrincipal() {
    _mostrarCabecalho();
    print('🏠 MENU PRINCIPAL');
    print('─' * _larguraPadrao);
    print('1. 📊 Dashboard Tempo Real');
    print('2. 👥 Gerenciar Funcionários');
    print('3. 📋 Logs e Relatórios');
    print('4. 🎛️  Controles Manuais');
    print('0. 🚪 Sair');
    print('─' * _larguraPadrao);
  }

  Future<void> _processarEscolhaMenu() async {
    stdout.write('Escolha uma opção: ');
    String? opcao = await _readLineAsync();

    switch (opcao) {
      case '1':
        if (!_dashboardRodando) {
          _iniciarDashboardBackground();
        } else {
          await _pararDashboardBackground();
        }
        break;
      case '2':
        await _menuFuncionarios();
        break;
      case '3':
        await _menuLogs();
        break;
      case '4':
        await _menuControles();
        break;
      case '0':
        _sair();
        break;
      default:
        print('❌ Opção inválida!');
        await _aguardarTecla();
    }
  }

  Future<String?> _readLineAsync() async {
    try {
      return await _inputLines.first;
    } catch (e) {
      return null;
    }
  }

  String pad(String s, int w) {
    final textoLimpo = s.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
    if (textoLimpo.length >= w) {
      if (textoLimpo.length > w) {
        return textoLimpo.substring(0, w);
      }
      return s;
    }
    return s + ' ' * (w - textoLimpo.length);
  }

  String _linhaTabela(List<int> larguras, List<String> cols) {
    final innerWidth = _larguraPadrao - 2;
    final paddedParts = <String>[];
    int cleanLen = 0;
    for (int i = 0; i < cols.length; i++) {
      final p = pad(cols[i], larguras[i]);
      paddedParts.add(p);
      final clean = p.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
      cleanLen += clean.length;
    }
    final sepCount = cols.length - 1;
    final innerCleanLen = cleanLen + sepCount;
    final faltando = innerWidth - innerCleanLen;
    final spaces = faltando > 0 ? ' ' * faltando : '';
    return '│${paddedParts.join('│')}$spaces│';
  }

  String _divisorTabela(List<int> larguras) {
    final innerWidth = _larguraPadrao - 2;
    final inner = List.generate(larguras.length, (i) => '─' * larguras[i]).join('┼');
    final faltando = innerWidth - inner.length;
    final extra = faltando > 0 ? '─' * faltando : '';
    return '├$inner$extra┤';
  }

  String _padInner(String s) {
    const int innerWidth = _larguraPadrao - 4;
    final textoLimpo = s.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
    String conteudo = textoLimpo;
    if (textoLimpo.length > innerWidth) {
      conteudo = '${textoLimpo.substring(0, innerWidth - 3)}...';
    }
    final padSpaces = innerWidth - conteudo.length;
    final espacos = padSpaces > 0 ? padSpaces : 0;
    return '│ $conteudo${' ' * espacos} │';
  }

  String _criarLinhaBorda({bool inicio = false, bool meio = false, bool fim = false}) {
    if (inicio) {
      return '┌${'─' * (_larguraPadrao - 2)}┐';
    }
    if (meio) {
      return '├${'─' * (_larguraPadrao - 2)}┤';
    }
    if (fim) {
      return '└${'─' * (_larguraPadrao - 2)}┘';
    }
    return '─' * _larguraPadrao;
  }

  String _primeiroNome(String nomeCompleto) {
    final n = nomeCompleto.trim();
    if (n.isEmpty) return '';
    final partes = n.split(RegExp(r'\s+'));
    return partes.isNotEmpty ? partes.first : n;
  }

  String _padCelula(String texto, int largura, {String? alinhamento = 'esquerda'}) {
    final textoLimpo = texto.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
    final comprimento = textoLimpo.length;
    if (comprimento >= largura) {
      return texto.substring(0, largura);
    }
    final espacos = largura - comprimento;
    if (alinhamento == 'direita') {
      return ' ' * espacos + texto;
    } else if (alinhamento == 'centro') {
      final esquerdaEspacos = espacos ~/ 2;
      final direitaEspacos = espacos - esquerdaEspacos;
      return ' ' * esquerdaEspacos + texto + ' ' * direitaEspacos;
    }
    return texto + ' ' * espacos;
  }

  String _formatResumoSistema(Map<String, dynamic> data) {
    final sensores = data['sensores'] as Map<String, dynamic>?;
    final climatizador = data['climatizador'] as Map<String, dynamic>?;
    final comandoIlum = data['comando_iluminacao_atual'] ?? 'auto';
    final tagsVal = data['tags_presentes'] ?? data['tags'] ?? [];
    String funcionariosStr;
    final nomesVal = data['nomes_presentes'];
    if (nomesVal is List && nomesVal.isNotEmpty) {
      funcionariosStr = nomesVal.join(', ');
    } else {
      if (tagsVal is List) {
        funcionariosStr = tagsVal.isEmpty ? 'Nenhuma tag detectada' : tagsVal.join(', ');
      } else {
        funcionariosStr = tagsVal.toString();
      }
    }

    final temp = sensores != null && sensores['temperatura'] != null
        ? '${(sensores['temperatura'] as num).toDouble().toStringAsFixed(1)}°C'
        : 'N/A';
    final hum = sensores != null && sensores['humidade'] != null
        ? '${(sensores['humidade'] as num).toDouble().toStringAsFixed(1)}%'
        : 'N/A';
    int? lumiVal;
    if (sensores != null) {
      if (sensores.containsKey('luminosidade') && sensores['luminosidade'] != null) {
        var v = sensores['luminosidade'];
        if (v is num) {
          lumiVal = v.toInt();
        } else if (v is String) {
          lumiVal = int.tryParse(v) ?? 0;
        }
      }
    }
    if (lumiVal == null) {
      try {
        final obj = sistemaController.ultimaSensorData;
        if (obj != null) {
          lumiVal = obj.luminosidade;
        }
      } catch (_) {}
    }

    final lumi = lumiVal != null ? '$lumiVal%' : 'N/A';
    final pessoas = sensores != null && sensores['pessoas'] != null ? sensores['pessoas'].toString() : '0';

    List<String> lines = [];

    final linha1 = 'Temperatura: ${pad(temp, 8)}  Umiddade: ${pad(hum, 8)}  Luz: ${pad(lumi, 6)}  Pessoas: $pessoas';
    lines.add(_padInner(linha1));

    final linha2 = 'Funcionarios: $funcionariosStr';
    lines.add(_padInner(linha2));

    if (climatizador != null) {
      final ligado = climatizador['ligado'] == true ? '🟢 LIGADO' : '🔴 DESLIGADO';
      final vel = climatizador['velocidade']?.toString() ?? '-';
      final umid = climatizador['umidificando'] == true ? 'SIM' : 'NÃO';
      final linha3 = 'Climatizador: ${pad(ligado, 12)}  Ventilacao: ${pad(vel, 3)}  Umidificador: $umid';
      lines.add(_padInner(linha3));
    } else {
      lines.add(_padInner('Climatizador: DESCONECTADO'));
    }

    final linha4 = 'Comando Iluminacao: ${comandoIlum.toString().toUpperCase()}';
    lines.add(_padInner(linha4));

    return lines.join('\n');
  }

  Future<void> _menuFuncionarios() async {
    while (true) {
      _mostrarCabecalho();
      print('👥 GERENCIAR FUNCIONÁRIOS');
      print('─' * _larguraPadrao);
      print('1. 📋 Listar Funcionários');
      print('2. ➕ Cadastrar Funcionário');
      print('3. ✏️  Editar Funcionário');
      print('4. 🗑️  Excluir Funcionário');
      print('0. ⬅️  Voltar');
      print('─' * _larguraPadrao);

      stdout.write('Escolha uma opção: ');
      String? opcao = await _readLineAsync();

      switch (opcao) {
        case '1':
          await _listarFuncionarios();
          break;
        case '2':
          await _cadastrarFuncionario();
          break;
        case '3':
          await _editarFuncionario();
          break;
        case '4':
          await _excluirFuncionario();
          break;
        case '0':
          return;
        default:
          print('❌ Opção inválida!');
          await _aguardarTecla();
      }
    }
  }

  Future<void> _listarFuncionarios() async {
    _mostrarCabecalho();
    print('👥 LISTA DE FUNCIONÁRIOS');
    print('─' * _larguraPadrao);

    try {
      List<Funcionario> funcionarios = await funcionarioService.listarTodos();

      if (funcionarios.isEmpty) {
        print('📭 Nenhum funcionário cadastrado no sistema.');
      } else {
        print('Total: ${funcionarios.length} funcionário(s) cadastrado(s)\n');

        const larguras = [10, 40, 8, 7, 13];
        print(_criarLinhaBorda(inicio: true));
        print(_linhaTabela(larguras, ['Matríc.', 'Nome Completo', 'Temp.°C', 'Lumi.%', 'Tag NFC']));
        print(_divisorTabela(larguras));

        for (Funcionario func in funcionarios) {
          final row = _linhaTabela(larguras, [
            func.matricula.toString(),
            '${func.nome} ${func.sobrenome}',
            func.tempPreferida.toStringAsFixed(1),
            func.lumiPreferida.toString(),
            func.tagNfc ?? 'N/A',
          ]);
          print(row);
        }

        print(_criarLinhaBorda(fim: true));
      }
    } catch (e) {
      print('❌ Erro ao listar funcionários: $e');
    }

    await _aguardarTecla();
  }

  Future<void> _cadastrarFuncionario() async {
    _mostrarCabecalho();
    print('👤 CADASTRAR NOVO FUNCIONÁRIO');
    print('─' * _larguraPadrao);

    try {
      stdout.write('Nome: ');
      String? nome = await _readLineAsync();
      if (nome == null || nome.trim().isEmpty) {
        print('❌ Nome é obrigatório!');
        await _aguardarTecla();
        return;
      }

      stdout.write('Sobrenome: ');
      String? sobrenome = await _readLineAsync();
      if (sobrenome == null || sobrenome.trim().isEmpty) {
        print('❌ Sobrenome é obrigatório!');
        await _aguardarTecla();
        return;
      }

      stdout.write('Matrícula: ');
      String? matriculaStr = await _readLineAsync();
      if (matriculaStr == null || matriculaStr.trim().isEmpty) {
        print('❌ Matrícula é obrigatória!');
        await _aguardarTecla();
        return;
      }

      int? matricula = int.tryParse(matriculaStr.trim());
      if (matricula == null) {
        print('❌ Matrícula deve ser um número válido!');
        await _aguardarTecla();
        return;
      }

      stdout.write('Senha: ');
      String? senha = await _readLineAsync();
      if (senha == null || senha.trim().isEmpty) {
        senha = 'default123';
      }

      stdout.write('Temperatura preferida (°C) [padrão: 24]: ');
      String? tempStr = await _readLineAsync();
      double tempPreferida = 24.0;
      if (tempStr != null && tempStr.trim().isNotEmpty) {
        double? temp = double.tryParse(tempStr.trim());
        if (temp != null) tempPreferida = temp;
      }

      stdout.write('Luminosidade preferida (%) [padrão: 70]: ');
      String? lumiStr = await _readLineAsync();
      int lumiPreferida = 70;
      if (lumiStr != null && lumiStr.trim().isNotEmpty) {
        int? lumi = int.tryParse(lumiStr.trim());
        if (lumi != null && (lumi >= 0 && lumi <= 100)) {
          lumiPreferida = lumi;
        }
      }

      print('Deseja aproximar a tag do ESP agora para capturar automaticamente? (s/N)');
      stdout.write('> ');
      String? resp = await _readLineAsync();

      String? tagNfc;
      if (resp != null && resp.trim().toLowerCase() == 's') {
        print('\nAtivando modo cadastro no ESP e aguardando tag por até 15 segundos...');
        try {
          await firebaseService.limparUltimaTag();
          await Future.delayed(Duration(milliseconds: 500));
        } catch (_) {}
        try {
          await firebaseService.setModoCadastro(true);
          await Future.delayed(Duration(milliseconds: 800));
        } catch (_) {}

        String? encontrada;
        final int maxAttempts = 20;
        for (int i = 0; i < maxAttempts; i++) {
          try {
            encontrada = await firebaseService.lerUltimaTag();
          } catch (e) {
            encontrada = null;
          }

          print('  > Tentativa ${i + 1}/$maxAttempts - valor lido: ${encontrada ?? 'null'}');

          if (encontrada != null && encontrada.isNotEmpty && encontrada != 'null') {
            tagNfc = encontrada;
            print('\n🏷️ Tag capturada: $tagNfc');
            await firebaseService.limparUltimaTag();
            break;
          }

          await Future.delayed(Duration(seconds: 1));
        }

        if (tagNfc == null) {
          print('\n⏳ Tempo esgotado. Nenhuma tag detectada.');
        }

        try {
          await firebaseService.setModoCadastro(false);
        } catch (_) {}
      } else {
        stdout.write('Tag NFC (opcional): ');
        tagNfc = await _readLineAsync();
        if (tagNfc != null && tagNfc.trim().isEmpty) {
          tagNfc = null;
        }
      }

      Funcionario novoFunc = Funcionario(
        matricula: matricula,
        nome: nome.trim(),
        sobrenome: sobrenome.trim(),
        senha: senha.trim(),
        tempPreferida: tempPreferida,
        lumiPreferida: lumiPreferida,
        tagNfc: tagNfc?.trim(),
      );

      bool sucesso = await funcionarioService.salvar(novoFunc);

      if (sucesso) {
        print('\n✅ Funcionário cadastrado com sucesso!');
      } else {
        print('\n❌ Erro ao salvar funcionário no banco de dados!');
      }

      print('📋 Resumo:');
      print('   Nome: ${novoFunc.nome} ${novoFunc.sobrenome}');
      print('   Matrícula: ${novoFunc.matricula}');
      print('   Temp. Preferida: ${novoFunc.tempPreferida}°C');
      print('   Lumi. Preferida: ${novoFunc.lumiPreferida}%');
      if (novoFunc.tagNfc != null) {
        print('   Tag NFC: ${novoFunc.tagNfc}');
      }
    } catch (e) {
      print('❌ Erro no cadastro: $e');
    }

    await _aguardarTecla();
  }

  Future<void> _editarFuncionario() async {
    _mostrarCabecalho();
    print('✏️ EDITAR FUNCIONÁRIO');
    print('─' * _larguraPadrao);

    try {
      stdout.write('Digite a matrícula do funcionário: ');
      String? matriculaStr = await _readLineAsync();
      if (matriculaStr == null || matriculaStr.trim().isEmpty) {
        print('❌ Matrícula é obrigatória!');
        await _aguardarTecla();
        return;
      }

      int? matricula = int.tryParse(matriculaStr.trim());
      if (matricula == null) {
        print('❌ Matrícula deve ser um número válido!');
        await _aguardarTecla();
        return;
      }

      Funcionario? funcionario = await funcionarioService.buscarPorMatriculaUnica(matricula);
      if (funcionario == null) {
        print('❌ Funcionário não encontrado!');
        await _aguardarTecla();
        return;
      }

      print('\n📋 Dados atuais:');
      print('   Nome: ${funcionario.nome} ${funcionario.sobrenome}');
      print('   Temp. Preferida: ${funcionario.tempPreferida}°C');
      print('   Lumi. Preferida: ${funcionario.lumiPreferida}%');
      print('   Tag NFC: ${funcionario.tagNfc ?? "N/A"}');
      print('');

      stdout.write('Nova temperatura [${funcionario.tempPreferida}°C]: ');
      String? novaTemp = await _readLineAsync();
      double? temperatura = funcionario.tempPreferida;
      if (novaTemp != null && novaTemp.trim().isNotEmpty) {
        double? temp = double.tryParse(novaTemp.trim());
        if (temp != null) temperatura = temp;
      }

      stdout.write('Nova luminosidade [${funcionario.lumiPreferida}%]: ');
      String? novaLumi = await _readLineAsync();
      int? luminosidade = funcionario.lumiPreferida;
      if (novaLumi != null && novaLumi.trim().isNotEmpty) {
        int? lumi = int.tryParse(novaLumi.trim());
        if (lumi != null && (lumi >= 0 && lumi <= 100)) {
          luminosidade = lumi;
        }
      }

      Funcionario funcionarioAtualizado = Funcionario(
        id: funcionario.id,
        matricula: funcionario.matricula,
        nome: funcionario.nome,
        sobrenome: funcionario.sobrenome,
        senha: funcionario.senha,
        tempPreferida: temperatura,
        lumiPreferida: luminosidade,
        tagNfc: funcionario.tagNfc,
        createdAt: funcionario.createdAt,
        updatedAt: DateTime.now(),
      );

      bool sucesso = await funcionarioService.atualizar(funcionarioAtualizado);

      if (sucesso) {
        print('\n✅ Funcionário atualizado com sucesso!');
      } else {
        print('❌ Erro ao atualizar funcionário!');
      }
    } catch (e) {
      print('❌ Erro na edição: $e');
    }

    await _aguardarTecla();
  }

  Future<void> _excluirFuncionario() async {
    _mostrarCabecalho();
    print('🗑️ EXCLUIR FUNCIONÁRIO');
    print('─' * _larguraPadrao);

    try {
      stdout.write('Digite a matrícula do funcionário: ');
      String? matriculaStr = await _readLineAsync();
      if (matriculaStr == null || matriculaStr.trim().isEmpty) {
        print('❌ Matrícula é obrigatória!');
        await _aguardarTecla();
        return;
      }

      int? matricula = int.tryParse(matriculaStr.trim());
      if (matricula == null) {
        print('❌ Matrícula deve ser um número válido!');
        await _aguardarTecla();
        return;
      }

      Funcionario? funcionario = await funcionarioService.buscarPorMatriculaUnica(matricula);
      if (funcionario == null) {
        print('❌ Funcionário não encontrado!');
        await _aguardarTecla();
        return;
      }

      print('\n⚠️ Você está prestes a excluir:');
      print('   Nome: ${funcionario.nome} ${funcionario.sobrenome}');
      print('   Matrícula: ${funcionario.matricula}');
      print('');

      stdout.write('Confirma a exclusão? (s/N): ');
      String? confirmacao = await _readLineAsync();

      if (confirmacao == null || !['s', 'S', 'sim', 'SIM'].contains(confirmacao.trim())) {
        print('❌ Exclusão cancelada!');
        await _aguardarTecla();
        return;
      }

      bool sucesso = await funcionarioService.excluir(funcionario.matricula);

      if (sucesso) {
        print('\n✅ Funcionário excluído com sucesso!');
      } else {
        print('❌ Erro ao excluir funcionário!');
      }
    } catch (e) {
      print('❌ Erro na exclusão: $e');
    }

    await _aguardarTecla();
  }

  Future<void> _menuLogs() async {
    while (true) {
      _mostrarCabecalho();
      print('📋 LOGS E RELATÓRIOS');
      print('─' * _larguraPadrao);
      print('1. 📊 Logs Recentes');
      print('2. 📈 Relatório Diário');
      print('3. 📅 Relatório por Período');
      print('4. 👤 Logs por Funcionário');
      print('5. 🗂️ Saídas IoT (mensagens operacionais)');
      print('0. ⬅️  Voltar');
      print('─' * _larguraPadrao);

      stdout.write('Escolha uma opção: ');
      String? opcao = await _readLineAsync();

      switch (opcao) {
        case '1':
          await _mostrarLogsRecentes();
          break;
        case '2':
          await _relatorioDiario();
          break;
        case '3':
          await _relatorioPorPeriodo();
          break;
        case '4':
          await _logsPorFuncionario();
          break;
        case '5':
          await _mostrarSaidasIoT();
          break;
        case '0':
          return;
        default:
          print('❌ Opção inválida!');
          await _aguardarTecla();
      }
    }
  }

  Future<void> _mostrarLogsRecentes() async {
    _mostrarCabecalho();
    print('📊 LOGS RECENTES');
    print('─' * _larguraPadrao);

    try {
      List<LogEntry> logs = await logService.listarRecentes();

      if (logs.isEmpty) {
        print('📭 Nenhum log encontrado no sistema.');
      } else {
        print('Total de registros: ${logs.length}');
        print('');
        const larguras = [8, 10, 8, 10, 42];
        print(_criarLinhaBorda(inicio: true));
        print(_linhaTabela(larguras, ['Tipo', 'Data', 'Hora', 'Matríc.', 'Nome do Funcionário']));
        print(_divisorTabela(larguras));

        for (LogEntry log in logs.take(20)) {
          String data = log.createdAt?.toString().substring(0, 10) ?? 'N/A';
          String hora = log.createdAt?.toString().substring(11, 19) ?? 'N/A';
          String tipo = log.tipo.toUpperCase();
          String matricula = log.matricula ?? 'N/A';
          String nome = log.nomeCompleto ?? 'N/A';

          String tipoColor = colorTipo(tipo.toLowerCase());

          final row = _linhaTabela(larguras, [tipoColor, data, hora, matricula, nome]);
          print(row);
        }

        print(_criarLinhaBorda(fim: true));

        if (logs.length > 20) {
          print('\n⚠️ Mostrando apenas os 20 registros mais recentes.');
        }
      }
    } catch (e) {
      print('❌ Erro ao buscar logs: $e');
    }

    await _aguardarTecla();
  }

  Future<void> _mostrarSaidasIoT() async {
    _mostrarCabecalho();
    print('🗂️ SAÍDAS OPERACIONAIS (IoT) - MODO AO VIVO');
    print('─' * _larguraPadrao);

    if (saidaService == null) {
      print('⚠️ Serviço de saídas não configurado.');
      await _aguardarTecla();
      return;
    }

    try {
      List<String> linhas = saidaService!.listar(limite: 200);
      if (linhas.isEmpty) {
        print('📭 Nenhuma saída registrada. Aguardando novas entradas...');
      } else {
        print('Mostrando ${linhas.length} linhas recentes:\n');
        for (String l in linhas) {
          print(l);
        }
      }

      print('\n⏱️  Sessão ao vivo: novas saídas aparecerão abaixo. Pressione ENTER para sair.');

      StreamSubscription<String>? saidaSub;
      StreamSubscription<String>? teclaSub;

      final completer = Completer<void>();

      saidaSub = saidaService!.stream.listen((novaLinha) {
        print(novaLinha);
      });

      teclaSub = _inputLines.listen((line) async {
        final t = line.trim().toLowerCase();
        if (t == '' || t == 'q') {
          await saidaSub?.cancel();
          await teclaSub?.cancel();
          completer.complete();
        }
      });

      await completer.future;

      print('\nDeseja limpar o buffer de saídas? (s/N)');
      stdout.write('> ');
      String? resp = await _readLineAsync();
      if (resp != null && resp.trim().toLowerCase() == 's') {
        saidaService!.limpar();
        print('✅ Buffer de saídas limpo.');
      }
    } catch (e) {
      print('❌ Erro ao mostrar saídas em tempo real: $e');
    }

    await _aguardarTecla();
  }

  Future<void> _relatorioDiario() async {
    _mostrarCabecalho();
    print('📈 RELATÓRIO DIÁRIO');
    print('─' * _larguraPadrao);

    try {
      DateTime hoje = DateTime.now();
      DateTime inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);
      DateTime fimHoje = inicioHoje.add(Duration(days: 1));

      print('📅 Data: ${inicioHoje.day.toString().padLeft(2, '0')}/${inicioHoje.month.toString().padLeft(2, '0')}/${inicioHoje.year}');
      print('─' * _larguraPadrao);

      List<LogEntry> logs = await logService.listarPorPeriodo(inicioHoje, fimHoje);

      if (logs.isEmpty) {
        print('📭 Nenhum registro encontrado para hoje.');
      } else {
        print('📊 Total de registros: ${logs.length}');
        print('');

        Map<String, int> acoesPorTipo = {};
        for (var log in logs) {
          acoesPorTipo[log.tipo] = (acoesPorTipo[log.tipo] ?? 0) + 1;
        }

        print('📋 Resumo por tipo de ação:');
        acoesPorTipo.forEach((tipo, quantidade) {
          String emoji = tipo == 'entrada' ? '🔓' : '🔒';
          print('   • $emoji $tipo: $quantidade');
        });

        print('\n🕐 Últimos 10 registros:');
        var ultimosLogs = logs.take(10);
        for (var log in ultimosLogs) {
          String data = log.createdAt?.toString().substring(0, 10) ?? 'N/A';
          String hora = log.createdAt?.toString().substring(11, 19) ?? 'N/A';
          String tipo = log.tipo.toUpperCase();
          String matricula = (log.matricula ?? 'N/A');
          String nome = (log.nomeCompleto ?? 'N/A');
          String tipoColor = colorTipo(tipo.toLowerCase());

          print('   [$data $hora] $tipoColor - Mat: $matricula - $nome');
        }
      }
    } catch (e) {
      print('❌ Erro ao gerar relatório: $e');
    }

    await _aguardarTecla();
  }

  Future<void> _relatorioPorPeriodo() async {
    _mostrarCabecalho();
    print('📅 RELATÓRIO POR PERÍODO');
    print('─' * _larguraPadrao);

    try {
      print('📅 Digite o período desejado:');
      print('');

      stdout.write('Data inicial (dd/mm/aaaa): ');
      String? dataInicialStr = await _readLineAsync();
      if (dataInicialStr == null || dataInicialStr.trim().isEmpty) {
        print('❌ Data inicial é obrigatória!');
        await _aguardarTecla();
        return;
      }

      stdout.write('Data final (dd/mm/aaaa): ');
      String? dataFinalStr = await _readLineAsync();
      if (dataFinalStr == null || dataFinalStr.trim().isEmpty) {
        print('❌ Data final é obrigatória!');
        await _aguardarTecla();
        return;
      }

      List<String> partesInicial = dataInicialStr.split('/');
      List<String> partesFinal = dataFinalStr.split('/');

      if (partesInicial.length != 3 || partesFinal.length != 3) {
        print('❌ Formato de data inválido! Use dd/mm/aaaa');
        await _aguardarTecla();
        return;
      }

      DateTime dataInicial = DateTime(int.parse(partesInicial[2]), int.parse(partesInicial[1]), int.parse(partesInicial[0]));

      DateTime dataFinal = DateTime(int.parse(partesFinal[2]), int.parse(partesFinal[1]), int.parse(partesFinal[0]), 23, 59, 59);

      print('\n🔍 Buscando logs de ${dataInicial.day.toString().padLeft(2, '0')}/${dataInicial.month.toString().padLeft(2, '0')}/${dataInicial.year} até ${dataFinal.day.toString().padLeft(2, '0')}/${dataFinal.month.toString().padLeft(2, '0')}/${dataFinal.year}...');

      List<LogEntry> logs = await logService.listarPorPeriodo(dataInicial, dataFinal);

      if (logs.isEmpty) {
        print('📭 Nenhum registro encontrado no período especificado.');
      } else {
        print('📊 Total de registros: ${logs.length}');
        print('');

        Map<String, int> estatisticas = {};
        Map<String, List<LogEntry>> logsPorFuncionario = {};

        for (var log in logs) {
          estatisticas[log.tipo] = (estatisticas[log.tipo] ?? 0) + 1;

          String chave = '${log.matricula} - ${log.nomeCompleto ?? 'N/A'}';
          logsPorFuncionario[chave] = logsPorFuncionario[chave] ?? [];
          logsPorFuncionario[chave]!.add(log);
        }

        print('\n📋 Registros (Tipo, Data, Hora, Matrícula, Nome):');
        for (var log in logs) {
          String data = log.createdAt?.toString().substring(0, 10) ?? 'N/A';
          String hora = log.createdAt?.toString().substring(11, 19) ?? 'N/A';
          String tipo = log.tipo.toUpperCase();
          String matricula = (log.matricula ?? 'N/A');
          String nome = (log.nomeCompleto ?? 'N/A');
          String tipoColor = colorTipo(tipo.toLowerCase());

          print('   - $tipoColor, $data, $hora, $matricula, $nome');
        }
      }
    } catch (e) {
      print('❌ Erro ao gerar relatório: $e');
    }

    await _aguardarTecla();
  }

  Future<void> _logsPorFuncionario() async {
    _mostrarCabecalho();
    print('👤 LOGS POR FUNCIONÁRIO');
    print('─' * _larguraPadrao);

    try {
      stdout.write('Digite a matrícula do funcionário: ');
      String? matriculaStr = await _readLineAsync();
      if (matriculaStr == null || matriculaStr.trim().isEmpty) {
        print('❌ Matrícula é obrigatória!');
        await _aguardarTecla();
        return;
      }

      int? matricula = int.tryParse(matriculaStr.trim());
      if (matricula == null) {
        print('❌ Matrícula deve ser um número válido!');
        await _aguardarTecla();
        return;
      }

      Funcionario? funcionario = await funcionarioService.buscarPorMatriculaUnica(matricula);
      if (funcionario == null) {
        print('❌ Funcionário não encontrado!');
        await _aguardarTecla();
        return;
      }

      print('\n👤 Funcionário: ${funcionario.nome} ${funcionario.sobrenome}');
      print('📊 Buscando registros...');

      List<LogEntry> logs = await logService.listarPorFuncionario(matricula);

      if (logs.isEmpty) {
        print('📭 Nenhum registro encontrado para este funcionário.');
      } else {
        print('📋 Total de registros: ${logs.length}');
        print('');

        Map<String, int> estatisticas = {};
        for (var log in logs) {
          estatisticas[log.tipo] = (estatisticas[log.tipo] ?? 0) + 1;
        }

        print('\n📋 Registros (Tipo, Data, Hora, Matrícula, Nome):');
        var ultimosLogs = logs.take(15);
        for (var log in ultimosLogs) {
          String data = log.createdAt?.toString().substring(0, 10) ?? 'N/A';
          String hora = log.createdAt?.toString().substring(11, 19) ?? 'N/A';
          String tipo = log.tipo.toUpperCase();
          String matricula = (log.matricula ?? 'N/A');
          String nome = (log.nomeCompleto ?? 'N/A');
          String tipoColor = colorTipo(tipo.toLowerCase());

          print('   - $tipoColor, $data, $hora, $matricula, $nome');
        }
      }
    } catch (e) {
      print('❌ Erro ao buscar logs: $e');
    }

    await _aguardarTecla();
  }

  Future<void> _menuControles() async {
    while (true) {
      _mostrarCabecalho();
      print('🎛️ CONTROLES MANUAIS');
      print('─' * _larguraPadrao);
      print('1. ❄️  Controlar Climatizador');
      print('2. 💡 Controlar Iluminação');
      print('3. 🔄 Voltar ao Modo Automático (Climatizador + Iluminação)');
      print('4. 🧪 Modo Teste');
      print('0. ⬅️  Voltar');
      print('─' * _larguraPadrao);

      stdout.write('Escolha uma opção: ');
      String? opcao = await _readLineAsync();

      switch (opcao) {
        case '1':
          await _controlarClimatizador();
          break;
        case '2':
          await _controlarIluminacao();
          break;
        case '3':
          await _resetarSistema();
          break;
        case '4':
          await _modoTeste();
          break;
        case '0':
          return;
        default:
          print('❌ Opção inválida!');
          await _aguardarTecla();
      }
    }
  }

  Future<void> _controlarClimatizador() async {
    _mostrarCabecalho();
    print('❄️ CONTROLAR CLIMATIZADOR');
    print('─' * _larguraPadrao);

    try {
      EstadoClimatizador? estadoAtual = sistemaController.ultimoEstadoClima;

      if (estadoAtual != null) {
        print('📊 Estado Atual:');
        print('   Status: ${estadoAtual.ligado ? "🟢 LIGADO" : "🔴 DESLIGADO"}');
        print('   Velocidade Ventilador: ${estadoAtual.velocidade}');
        print('   Umidificando: ${estadoAtual.umidificando ? "SIM" : "NÃO"}');
        print('');
      }

      print('Opções:');
      print('1. ${estadoAtual?.ligado == true ? "🔴 Desligar" : "🟢 Ligar"}');
      print('2. 💨 Ajustar Velocidade');
      print('3. 💧 Toggle Umidificação');
      print('4. ⏲️  Ajustar Timer');
      print('5. 🔼 Toggle Aleta Vertical');
      print('6. ↔️  Toggle Aleta Horizontal');
      print('0. ⬅️ Voltar');

      stdout.write('Escolha uma opção: ');
      String? opcao = await _readLineAsync();

      switch (opcao) {
        case '1':
          bool novoStatus = !(estadoAtual?.ligado ?? false);

          if (novoStatus) {
            stdout.write('Deseja definir uma velocidade específica? (1-3, ou ENTER para velocidade padrão): ');
            String? velStr = await _readLineAsync();
            int? velocidade;

            if (velStr != null && velStr.trim().isNotEmpty) {
              velocidade = int.tryParse(velStr.trim());
              if (velocidade != null && (velocidade < 1 || velocidade > 3)) {
                print('❌ Velocidade inválida (deve ser 1-3)!');
                await _aguardarTecla();
                return;
              }
            }

            await sistemaController.enviarComandoClimatizador('power_on', velocidade: velocidade);
            String velMsg = velocidade != null ? ' com velocidade $velocidade' : '';
            print('✅ Climatizador ligado$velMsg!');
          } else {
            await sistemaController.enviarComandoClimatizador('power_off');
            print('✅ Climatizador desligado!');
          }
          break;

        case '2':
          if (estadoAtual?.ligado != true) {
            print('⚠ Climatizador precisa estar ligado para ajustar velocidade!');
            print('💡 Ligue o climatizador primeiro (opção 1).');
          } else {
            stdout.write('Velocidade do ventilador (1-3, ou ENTER para incrementar): ');
            String? velStr = await _readLineAsync();

            if (velStr == null || velStr.trim().isEmpty) {
              await sistemaController.enviarComandoClimatizador('velocidade');
              print('✅ Velocidade incrementada!');
            } else {
              int? novaVel = int.tryParse(velStr.trim());
              if (novaVel != null && novaVel >= 1 && novaVel <= 3) {
                await sistemaController.enviarComandoClimatizador('velocidade', velocidade: novaVel);
                print('✅ Ventilador ajustado para velocidade $novaVel!');
              } else {
                print('❌ Velocidade inválida (deve ser 1, 2 ou 3)!');
              }
            }
          }
          break;

        case '3':
          if (estadoAtual?.ligado != true) {
            print('⚠ Climatizador precisa estar ligado para controlar umidificação!');
          } else {
            await sistemaController.enviarComandoClimatizador('umidificar');
            print('✅ Umidificador alternado!');
          }
          break;

        case '4':
          if (estadoAtual?.ligado != true) {
            print('⚠ Climatizador precisa estar ligado para ajustar timer!');
          } else {
            await sistemaController.enviarComandoClimatizador('timer');
            print('✅ Timer ajustado!');
          }
          break;

        case '5':
          if (estadoAtual?.ligado != true) {
            print('⚠ Climatizador precisa estar ligado para controlar aletas!');
          } else {
            await sistemaController.enviarComandoClimatizador('aleta_v');
            print('✅ Aleta vertical alternada!');
          }
          break;

        case '6':
          if (estadoAtual?.ligado != true) {
            print('⚠ Climatizador precisa estar ligado para controlar aletas!');
          } else {
            await sistemaController.enviarComandoClimatizador('aleta_h');
            print('✅ Aleta horizontal alternada!');
          }
          break;

        case '0':
          return;

        default:
          print('❌ Opção inválida!');
      }
    } catch (e) {
      print('❌ Erro no controle: $e');
    }

    await _aguardarTecla();
  }

  Future<void> _controlarIluminacao() async {
    _mostrarCabecalho();
    print('💡 CONTROLAR ILUMINAÇÃO');
    print('─' * _larguraPadrao);

    try {
      stdout.write('Intensidade da iluminação (0-100%): ');
      String? intensidadeStr = await _readLineAsync();

      int? intensidade = int.tryParse(intensidadeStr ?? '');
      if (intensidade != null && intensidade >= 0 && intensidade <= 100) {
        final ok = await sistemaController.definirIluminacaoManual(intensidade);
        if (ok) {
          print('✅ Iluminação ajustada para $intensidade%!');
        } else {
          print('❌ Falha ao ajustar iluminação.');
        }
      } else {
        print('❌ Intensidade inválida (deve estar entre 0 e 100)!');
      }
    } catch (e) {
      print('❌ Erro no controle: $e');
    }

    await _aguardarTecla();
  }

  Future<void> _resetarSistema() async {
    _mostrarCabecalho();
    print('🔄 VOLTAR AO MODO AUTOMÁTICO');
    print('─' * _larguraPadrao);
    stdout.write('⚠️ Confirma que deseja retornar o climatizador ao modo AUTOMÁTICO? (s/N): ');
    String? confirmacao = await _readLineAsync();

    if (confirmacao != null && confirmacao.toLowerCase() == 's') {
      try {
        bool sucessoClimaInterno = await sistemaController.enviarComandoClimatizador('auto');
        bool sucessoClimaFirebase = false;
        try {
          sucessoClimaFirebase = await firebaseService.enviarComandoClimatizador('auto');
        } catch (_) {
          sucessoClimaFirebase = false;
        }

        bool sucessoIlum = await sistemaController.definirIluminacaoManual('auto');

        final sucessoClima = sucessoClimaInterno && sucessoClimaFirebase;
        if (sucessoClima && sucessoIlum) {
          print('✅ Climatizador e Iluminação retornaram ao modo AUTOMÁTICO com sucesso!');

          try {
            await sistemaController.processarDadosSensores();
            print('✅ Preferências recalculadas e publicadas para aplicação automática.');
          } catch (e) {
            print('⚠️ Falha ao recalcular/publicar preferências: $e');
          }

          try {
            int nivelPublicar = 0;

            final dados = sistemaController.ultimaSensorData;
            if (dados != null) {
              if (dados.pessoas == 0) {
                nivelPublicar = 0;
              } else {
                PreferenciasGrupo? prefs = await sistemaController.processarSolicitacaoPreferencias(dados.tags);
                if (prefs != null) {
                  nivelPublicar = prefs.luminosidadeUtilizada;
                } else {
                  nivelPublicar = dados.luminosidade > 0 ? dados.luminosidade : 50;
                }
              }
            }

            await firebaseService.enviarComandoIluminacao(nivelPublicar);
            print('✅ Publicado nível de iluminação desejado: $nivelPublicar%');
          } catch (e) {
            print('⚠️ Falha ao publicar nível de iluminação diretamente: $e');
          }
        } else if (sucessoClima && !sucessoIlum) {
          print('⚠️ Climatizador no modo AUTOMÁTICO, mas falha ao ajustar iluminação para AUTO.');
        } else if (!sucessoClima && sucessoIlum) {
          print('⚠️ Iluminação no modo AUTOMÁTICO, mas falha ao ajustar climatizador para AUTO.');
        } else {
          print('❌ Falha ao retornar ambos os sistemas para modo automático.');
        }
      } catch (e) {
        print('❌ Erro ao alterar modos: $e');
      }
    } else {
      print('❌ Operação cancelada.');
    }

    await _aguardarTecla();
  }

  Future<void> _modoTeste() async {
    _mostrarCabecalho();
    print('🧪 MODO TESTE');
    print('─' * _larguraPadrao);
    print('Este modo permite testar a comunicação com os sistemas.');
    print('');

    print('1. 🔥 Teste Firebase');
    print('2. 💾 Teste Banco de Dados');
    print('3. 📡 Teste ESP32');
    print('0. ⬅️ Voltar');

    stdout.write('Escolha um teste: ');
    String? opcao = await _readLineAsync();

    switch (opcao) {
      case '1':
        await _testarFirebase();
        break;
      case '2':
        await _testarBancoDados();
        break;
      case '3':
        await _testarEsp32();
        break;
      case '0':
        return;
      default:
        print('❌ Opção inválida!');
    }

    await _aguardarTecla();
  }

  Future<void> _testarFirebase() async {
    print('\n🔥 Testando conexão com Firebase...');

    try {
      DadosSensores? dados = await firebaseService.lerSensores();
      if (dados != null) {
        print('✅ Firebase conectado com sucesso!');
        print('📊 Última leitura:');
        print('   Temperatura: ${dados.temperatura}°C');
        print('   Umidade: ${dados.humidade}%');
        print('   Luz: ${dados.luminosidade}%');
        print('   Pessoas: ${dados.pessoas}');
        print('   Tags: ${dados.tags}');
      } else {
        print('⚠️ Firebase conectado, mas sem dados disponíveis.');
      }
    } catch (e) {
      print('❌ Erro na conexão com Firebase: $e');
    }
  }

  Future<void> _testarBancoDados() async {
    print('\n💾 Testando conexão com Banco de Dados...');

    try {
      List<Funcionario> funcionarios = await funcionarioService.listarTodos();
      print('✅ Banco de dados conectado com sucesso!');
      print('👥 Funcionários cadastrados: ${funcionarios.length}');

      List<LogEntry> logs = await logService.listarRecentes();
      print('📝 Logs recentes: ${logs.length}');
    } catch (e) {
      print('❌ Erro na conexão com banco: $e');
    }
  }

  Future<void> _testarEsp32() async {
    print('\n📡 Testando comunicação com ESP32...');

    try {
      await firebaseService.enviarComandoClimatizador('ligar:1');
      print('✅ Comando enviado ao ESP32!');
      print('   Teste: Ligar climatizador velocidade 1');

      await Future.delayed(Duration(seconds: 2));

      await firebaseService.enviarComandoClimatizador('desligar');
      print('✅ Comando de desligar enviado!');
    } catch (e) {
      print('❌ Erro na comunicação com ESP32: $e');
    }
  }

  void _sair() {
    _mostrarCabecalho();
    print('🚪 ENCERRANDO SISTEMA');
    print('─' * _larguraPadrao);
    print('Obrigado por usar o Sistema IoT Packbag!');
    print('Sistema encerrado com segurança.');
    _executando = false;
  }

  void _mostrarCabecalho() {
    if (Platform.isWindows) {
      Process.runSync('cls', [], runInShell: true);
    } else {
      Process.runSync('clear', [], runInShell: true);
    }

    print('╔${'═' * (_larguraPadrao - 2)}╗');
    print('║${_padCelula('🏭 Sistema IoT Packbag v2.0', _larguraPadrao - 2, alinhamento: 'centro')}║');
    print('║${_padCelula('Dashboard Console - Dart', _larguraPadrao - 2, alinhamento: 'centro')}║');
    print('╚${'═' * (_larguraPadrao - 2)}╝');
    print('');
  }

  Future<void> _aguardarTecla() async {
    print('\n⏎ Pressione ENTER para continuar...');
    await _readLineAsync();
  }
}
