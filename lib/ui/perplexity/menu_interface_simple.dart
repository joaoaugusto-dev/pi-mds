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

// Funções utilitárias (removidas as não utilizadas para simplificar o arquivo)

class MenuInterface {
  final FuncionarioService funcionarioService;
  final LogService logService;
  final FirebaseService firebaseService;
  final SaidaService? saidaService;
  final SistemaIotController sistemaController;
  bool _executando = true;
  bool _dashboardRodando = false;
  StreamSubscription<Map<String, dynamic>>?
  _dashboardSubs;
  StreamSubscription<String>? _keySubs;
  // Stream persistente de linhas do stdin (para leitura não-bloqueante)
  late final Stream<String> _inputLines;

  void _iniciarDashboardBackground() {
    if (_dashboardRodando) return;
    _dashboardRodando = true;
    _mostrarCabecalho();
    print(
      '📊 Dashboard iniciado em background. Atualizações aparecerão no console.',
    );
    print(
      '💡 Pressione ENTER para sair do dashboard e voltar ao menu principal.',
    );
    print('');

    // Desativar logs detalhados para não poluir o dashboard
    sistemaController.setVerbose(false);

    // Inscrever na stream do controller (atualiza periodicamente)
    _dashboardSubs = sistemaController
        .streamDadosTempoReal()
        .listen((data) {
          // Limpar algumas linhas para uma atualização mais suave
          print('\n' * 2);

          // Imprimir bloco formatado e compacto
          print('┌${'─' * 70}┐');
          print(
            '│ 📊 Dashboard IoT - ${DateTime.now().toString().substring(11, 19).padRight(46)}│',
          );
          print('├${'─' * 70}┤');
          print(_formatResumoSistema(data));
          print('├${'─' * 70}┤');
          print(
            '│ 💡 Pressione ENTER para sair do dashboard${' ' * 25}│',
          );
          print('└${'─' * 70}┘');
        });

    // Inscrever na stream de teclas (ENTER ou 'q' para sair do dashboard)
    _keySubs = _inputLines.listen((line) async {
      final t = line.trim().toLowerCase();
      if (t == '' || t == 'q') {
        // Parar dashboard sem interromper o background sync
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
    // Desativar verbose para não poluir o console quando o dashboard estiver parado
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
    _inputLines = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .asBroadcastStream();
  }

  Future<void> iniciar() async {
    print(
      '\n🏭 Sistema IoT Packbag - Dashboard Console',
    );
    print('Versão 2.0 - Dart/Firebase Edition');

    while (_executando) {
      _mostrarMenuPrincipal();
      await _processarEscolhaMenu();
    }
  }

  void _mostrarMenuPrincipal() {
    _mostrarCabecalho();
    print('🏠 MENU PRINCIPAL');
    print('─' * 70);
    print('1. 📊 Dashboard Tempo Real');
    print('2. 👥 Gerenciar Funcionários');
    print('3. 📋 Logs e Relatórios');
    print('4. 🎛️  Controles Manuais');
    print('0. 🚪 Sair');
    print('─' * 70);
  }

  Future<void> _processarEscolhaMenu() async {
    stdout.write('Escolha uma opção: ');
    String? opcao = await _readLineAsync();

    switch (opcao) {
      case '1':
        // Toggle dashboard em background: iniciar/parear sem bloquear
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

  // Ler uma linha do stdin de forma assíncrona (não bloqueante)
  Future<String?> _readLineAsync() async {
    try {
      return await _inputLines.first;
    } catch (e) {
      return null;
    }
  }

  // ignore: unused_element
  Future<void> _dashboardTempoReal() async {
    _mostrarCabecalho();
    print('📊 DASHBOARD TEMPO REAL');
    print('─' * 70);
    print(
      'Pressione Ctrl+C para voltar ao menu principal\n',
    );

    int contador = 0;
    while (contador < 10) {
      // Limitar a 10 atualizações para evitar loop infinito
      try {
        // Buscar dados do Firebase
        DadosSensores? dados =
            await firebaseService.lerSensores();

        if (dados != null) {
          // Limpar tela (simples)
          if (contador > 0) print('\n' * 2);

          // Imprimir um cartão bonito com os dados
          EstadoClimatizador? clima =
              sistemaController.ultimoEstadoClima;
          print('┌${'─' * 70}┐');
          print(
            '│ 🔄 Atualização: ${DateTime.now().toString().substring(0, 19).padRight(49)}│',
          );
          print('├${'─' * 70}┤');
          _printDadosCard(dados, clima);
          print('├${'─' * 70}┤');
          print(
            '│ 📱 Status do Sistema: ESP32: ✅  Firebase: ✅  Banco: ${await _verificarStatusBanco()}${' ' * 8}│',
          );
          print('└${'─' * 70}┘');
        } else {
          print(
            '⚠️  Aguardando dados do Firebase...',
          );
        }

        contador++;

        // Aguardar 3 segundos antes da próxima atualização
        await Future.delayed(
          Duration(seconds: 3),
        );
      } catch (e) {
        print(
          '❌ Erro ao atualizar dashboard: $e',
        );
        await Future.delayed(
          Duration(seconds: 5),
        );
        break;
      }
    }

    print(
      '\n📊 Dashboard encerrado. Voltando ao menu...',
    );
    await _aguardarTecla();
  }

  Future<String> _verificarStatusBanco() async {
    try {
      await funcionarioService.listarTodos();
      return '✅ Conectado';
    } catch (e) {
      return '❌ Erro';
    }
  }

  // Helpers de formatação para o dashboard
  String _padInner(String s) {
    const int innerWidth = 70;
    if (s.length > innerWidth - 3) {
      s = '${s.substring(0, innerWidth - 6)}...';
    }
    return '│ ${s.padRight(innerWidth - 1)}│';
  }

  String _formatResumoSistema(
    Map<String, dynamic> data,
  ) {
    final sensores =
        data['sensores'] as Map<String, dynamic>?;
    final climatizador =
        data['climatizador']
            as Map<String, dynamic>?;
    final comandoIlum =
        data['comando_iluminacao_atual'] ??
        'auto';
    final tagsVal =
        data['tags_presentes'] ??
        data['tags'] ??
        [];
    String tagsStr;
    if (tagsVal is List) {
      tagsStr = tagsVal.isEmpty
          ? 'Nenhuma tag detectada'
          : tagsVal.join(', ');
    } else {
      tagsStr = tagsVal.toString();
    }

    final temp =
        sensores != null &&
            sensores['temperatura'] != null
        ? '${(sensores['temperatura'] as num).toDouble().toStringAsFixed(1).padLeft(5)}°C'
        : '  N/A';
    final hum =
        sensores != null &&
            sensores['humidade'] != null
        ? '${(sensores['humidade'] as num).toDouble().toStringAsFixed(1).padLeft(5)}%'
        : '  N/A';
    // Luminosidade do sensor LDR
    int? lumiVal;
    if (sensores != null) {
      if (sensores.containsKey('luminosidade') &&
          sensores['luminosidade'] != null) {
        var v = sensores['luminosidade'];
        if (v is num) {
          lumiVal = v.toInt();
        } else if (v is String) {
          lumiVal = int.tryParse(v) ?? 0;
        }
      }
    }
    // Se não houver valor no payload, tentar obter do controller (última leitura tipada)
    if (lumiVal == null) {
      try {
        final obj =
            sistemaController.ultimaSensorData;
        if (obj != null) {
          lumiVal = obj.luminosidade;
        }
      } catch (_) {}
    }

    final lumi = lumiVal != null
        ? '${lumiVal.toString().padLeft(3)}%'
        : 'N/A';
    final pessoas =
        sensores != null &&
            sensores['pessoas'] != null
        ? sensores['pessoas'].toString().padLeft(
            2,
          )
        : ' 0';

    List<String> lines = [];
    lines.add(
      _padInner(
        '🌡 Temp: $temp   💧 Umid: $hum   💡 Luz: $lumi   👥 Pessoas: $pessoas',
      ),
    );
    lines.add(
      _padInner(
        '🏷️  Funcionários: ${tagsStr.padRight(35)}',
      ),
    );

    if (climatizador != null) {
      final ligado =
          climatizador['ligado'] == true
          ? '🟢 LIGADO  '
          : '🔴 DESLIGADO';
      final vel =
          climatizador['velocidade']
              ?.toString()
              .padLeft(2) ??
          '-';
      final umid =
          climatizador['umidificando'] == true
          ? 'SIM'
          : 'NÃO';
      lines.add(
        _padInner(
          '❄️  Clima: $ligado   Vent: $vel   Umidif: $umid',
        ),
      );
    } else {
      lines.add(
        _padInner(
          '❄️  Climatizador: 🔴 DESCONECTADO${' ' * 25}',
        ),
      );
    }

    lines.add(
      _padInner(
        '⚙️  Comando Iluminação: ${comandoIlum.toString().toUpperCase()}${' ' * 20}',
      ),
    );

    return lines.join('\n');
  }

  void _printDadosCard(
    DadosSensores dados,
    EstadoClimatizador? clima,
  ) {
    // linha de sensores
    print(
      _padInner(
        '🌡 Temperatura: ${dados.temperatura.toStringAsFixed(1)}°C   💧 Umidade: ${dados.humidade.toStringAsFixed(1)}%   💡 Luz: ${dados.luminosidade}%   👥 Pessoas: ${dados.pessoas}',
      ),
    );

    // tags
    print(
      _padInner(
        '🏷️  Tags: ${dados.tags.join(', ')}',
      ),
    );

    // clima
    if (clima != null) {
      final status = clima.ligado
          ? '🟢 LIGADO'
          : '🔴 DESLIGADO';
      print(
        _padInner(
          '❄️  Climatizador: $status   Ventilador: Vel. ${clima.velocidade}   Umidificando: ${clima.umidificando ? 'SIM' : 'NÃO'}',
        ),
      );
    } else {
      print(_padInner('❄️  Climatizador: N/D'));
    }
  }

  Future<void> _menuFuncionarios() async {
    while (true) {
      _mostrarCabecalho();
      print('👥 GERENCIAR FUNCIONÁRIOS');
      print('─' * 70);
      print('1. 📋 Listar Funcionários');
      print('2. ➕ Cadastrar Funcionário');
      print('3. ✏️  Editar Funcionário');
      print('4. 🗑️  Excluir Funcionário');
      print('0. ⬅️  Voltar');
      print('─' * 70);

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
    print('─' * 70);

    try {
      List<Funcionario> funcionarios =
          await funcionarioService.listarTodos();

      if (funcionarios.isEmpty) {
        print(
          '📭 Nenhum funcionário cadastrado no sistema.',
        );
      } else {
        print(
          'Total: ${funcionarios.length} funcionário(s) cadastrado(s)\n',
        );

        // Cabeçalho da tabela
        print(
          '┌─────────┬──────────────────────────┬─────────┬─────────┬──────────────┐',
        );
        print(
          '│ Matríc. │ Nome Completo            │ Temp.°C │ Lumi.%  │ Tag NFC      │',
        );
        print(
          '├─────────┼──────────────────────────┼─────────┼─────────┼──────────────┤',
        );

        for (Funcionario func in funcionarios) {
          String matricula = func.matricula
              .toString()
              .padRight(7);
          String nomeCompleto =
              '${func.nome} ${func.sobrenome}';
          String nome = nomeCompleto.length > 24
              ? '${nomeCompleto.substring(0, 21)}...'
              : nomeCompleto.padRight(24);
          String temp = func.tempPreferida
              .toStringAsFixed(1)
              .padLeft(7);
          String lumi = func.lumiPreferida
              .toString()
              .padLeft(7);
          String tag = (func.tagNfc ?? 'N/A')
              .padRight(12);

          print(
            '│ $matricula │ $nome │ $temp │ $lumi │ $tag │',
          );
        }

        print(
          '└─────────┴──────────────────────────┴─────────┴─────────┴──────────────┘',
        );
      }
    } catch (e) {
      print('❌ Erro ao listar funcionários: $e');
    }

    await _aguardarTecla();
  }

  Future<void> _cadastrarFuncionario() async {
    _mostrarCabecalho();
    print('👤 CADASTRAR NOVO FUNCIONÁRIO');
    print('─' * 70);

    try {
      // Coletar dados do funcionário
      stdout.write('Nome: ');
      String? nome = await _readLineAsync();
      if (nome == null || nome.trim().isEmpty) {
        print('❌ Nome é obrigatório!');
        await _aguardarTecla();
        return;
      }

      stdout.write('Sobrenome: ');
      String? sobrenome = await _readLineAsync();
      if (sobrenome == null ||
          sobrenome.trim().isEmpty) {
        print('❌ Sobrenome é obrigatório!');
        await _aguardarTecla();
        return;
      }

      stdout.write('Matrícula: ');
      String? matriculaStr =
          await _readLineAsync();
      if (matriculaStr == null ||
          matriculaStr.trim().isEmpty) {
        print('❌ Matrícula é obrigatória!');
        await _aguardarTecla();
        return;
      }

      int? matricula = int.tryParse(
        matriculaStr.trim(),
      );
      if (matricula == null) {
        print(
          '❌ Matrícula deve ser um número válido!',
        );
        await _aguardarTecla();
        return;
      }

      stdout.write('Senha: ');
      String? senha = await _readLineAsync();
      if (senha == null || senha.trim().isEmpty) {
        senha = 'default123';
      }

      stdout.write(
        'Temperatura preferida (°C) [padrão: 24]: ',
      );
      String? tempStr = await _readLineAsync();
      double tempPreferida = 24.0;
      if (tempStr != null &&
          tempStr.trim().isNotEmpty) {
        double? temp = double.tryParse(
          tempStr.trim(),
        );
        if (temp != null) tempPreferida = temp;
      }

      stdout.write(
        'Luminosidade preferida (%) [padrão: 70]: ',
      );
      String? lumiStr = await _readLineAsync();
      int lumiPreferida = 70;
      if (lumiStr != null &&
          lumiStr.trim().isNotEmpty) {
        int? lumi = int.tryParse(lumiStr.trim());
        if (lumi != null &&
            lumi >= 0 &&
            lumi <= 100) {
          lumiPreferida = lumi;
        }
      }

      // Perguntar primeiro se deseja aproximar a tag do ESP para captura automática
      print(
        'Deseja aproximar a tag do ESP agora para capturar automaticamente? (s/N)',
      );
      stdout.write('> ');
      String? resp = await _readLineAsync();

      String? tagNfc;
      if (resp != null &&
          resp.trim().toLowerCase() == 's') {
        print(
          '\nAtivando modo cadastro no ESP e aguardando tag por até 15 segundos...',
        );
        // Limpar qualquer /ultima_tag residual e ativar modo cadastro no ESP
        try {
          await firebaseService.limparUltimaTag();
          // pequena espera para garantir que o delete seja propagado
          await Future.delayed(
            Duration(milliseconds: 500),
          );
        } catch (_) {}
        try {
          await firebaseService.setModoCadastro(
            true,
          );
          // aguardar um pouco para o ESP entrar em modo cadastro e estar pronto para leitura
          await Future.delayed(
            Duration(milliseconds: 800),
          );
        } catch (_) {}

        // tentar ler a última tag periodicamente
        String? encontrada;
        final int maxAttempts =
            20; // checa a cada 1s (20s timeout)
        for (int i = 0; i < maxAttempts; i++) {
          try {
            encontrada = await firebaseService
                .lerUltimaTag();
          } catch (e) {
            encontrada = null;
          }

          // DEBUG: mostrar tentativa e valor lido (ajuda a diagnosticar timing)
          print(
            '  > Tentativa ${i + 1}/$maxAttempts - valor lido: ${encontrada ?? 'null'}',
          );

          if (encontrada != null &&
              encontrada.isNotEmpty &&
              encontrada != 'null') {
            tagNfc = encontrada;
            print('\n🏷️ Tag capturada: $tagNfc');
            // limpar no firebase para evitar reuso
            await firebaseService
                .limparUltimaTag();
            break;
          }

          await Future.delayed(
            Duration(seconds: 1),
          );
        }

        if (tagNfc == null) {
          print(
            '\n⏳ Tempo esgotado. Nenhuma tag detectada.',
          );
        }

        // Desativar modo cadastro (garantir que o ESP volte ao modo normal)
        try {
          await firebaseService.setModoCadastro(
            false,
          );
        } catch (_) {}
      } else {
        // Se não deseja aproximar, permitir digitar manualmente
        stdout.write('Tag NFC (opcional): ');
        tagNfc = await _readLineAsync();
        if (tagNfc != null &&
            tagNfc.trim().isEmpty) {
          tagNfc = null;
        }
      }

      // Criar funcionário
      Funcionario novoFunc = Funcionario(
        matricula: matricula,
        nome: nome.trim(),
        sobrenome: sobrenome.trim(),
        senha: senha.trim(),
        tempPreferida: tempPreferida,
        lumiPreferida: lumiPreferida,
        tagNfc: tagNfc?.trim(),
      );

      // Salvar no banco de dados
      bool sucesso = await funcionarioService
          .salvar(novoFunc);

      if (sucesso) {
        // Salvar preferência individual no cache MySQL para uso imediato
        // Preferencias agora estão armazenadas em `funcionarios` (colunas temp_preferida/lumi_preferida).
        // Não é mais necessário salvar uma cópia em preferencias_tags.

        print(
          '\n✅ Funcionário cadastrado com sucesso!',
        );
      } else {
        print(
          '\n❌ Erro ao salvar funcionário no banco de dados!',
        );
      }

      print('📋 Resumo:');
      print(
        '   Nome: ${novoFunc.nome} ${novoFunc.sobrenome}',
      );
      print(
        '   Matrícula: ${novoFunc.matricula}',
      );
      print(
        '   Temp. Preferida: ${novoFunc.tempPreferida}°C',
      );
      print(
        '   Lumi. Preferida: ${novoFunc.lumiPreferida}%',
      );
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
    print('─' * 70);

    try {
      stdout.write(
        'Digite a matrícula do funcionário: ',
      );
      String? matriculaStr =
          await _readLineAsync();
      if (matriculaStr == null ||
          matriculaStr.trim().isEmpty) {
        print('❌ Matrícula é obrigatória!');
        await _aguardarTecla();
        return;
      }

      int? matricula = int.tryParse(
        matriculaStr.trim(),
      );
      if (matricula == null) {
        print(
          '❌ Matrícula deve ser um número válido!',
        );
        await _aguardarTecla();
        return;
      }

      Funcionario? funcionario =
          await funcionarioService
              .buscarPorMatriculaUnica(matricula);
      if (funcionario == null) {
        print('❌ Funcionário não encontrado!');
        await _aguardarTecla();
        return;
      }

      print('\n📋 Dados atuais:');
      print(
        '   Nome: ${funcionario.nome} ${funcionario.sobrenome}',
      );
      print(
        '   Temp. Preferida: ${funcionario.tempPreferida}°C',
      );
      print(
        '   Lumi. Preferida: ${funcionario.lumiPreferida}%',
      );
      print(
        '   Tag NFC: ${funcionario.tagNfc ?? "N/A"}',
      );
      print('');

      stdout.write(
        'Nova temperatura [${funcionario.tempPreferida}°C]: ',
      );
      String? novaTemp = await _readLineAsync();
      double? temperatura =
          funcionario.tempPreferida;
      if (novaTemp != null &&
          novaTemp.trim().isNotEmpty) {
        double? temp = double.tryParse(
          novaTemp.trim(),
        );
        if (temp != null) temperatura = temp;
      }

      stdout.write(
        'Nova luminosidade [${funcionario.lumiPreferida}%]: ',
      );
      String? novaLumi = await _readLineAsync();
      int? luminosidade =
          funcionario.lumiPreferida;
      if (novaLumi != null &&
          novaLumi.trim().isNotEmpty) {
        int? lumi = int.tryParse(novaLumi.trim());
        if (lumi != null &&
            lumi >= 0 &&
            lumi <= 100) {
          luminosidade = lumi;
        }
      }

      // Criar funcionário atualizado
      Funcionario funcionarioAtualizado =
          Funcionario(
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

      bool sucesso = await funcionarioService
          .atualizar(funcionarioAtualizado);

      if (sucesso) {
        print(
          '\n✅ Funcionário atualizado com sucesso!',
        );
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
    print('─' * 70);

    try {
      stdout.write(
        'Digite a matrícula do funcionário: ',
      );
      String? matriculaStr =
          await _readLineAsync();
      if (matriculaStr == null ||
          matriculaStr.trim().isEmpty) {
        print('❌ Matrícula é obrigatória!');
        await _aguardarTecla();
        return;
      }

      int? matricula = int.tryParse(
        matriculaStr.trim(),
      );
      if (matricula == null) {
        print(
          '❌ Matrícula deve ser um número válido!',
        );
        await _aguardarTecla();
        return;
      }

      Funcionario? funcionario =
          await funcionarioService
              .buscarPorMatriculaUnica(matricula);
      if (funcionario == null) {
        print('❌ Funcionário não encontrado!');
        await _aguardarTecla();
        return;
      }

      print('\n⚠️ Você está prestes a excluir:');
      print(
        '   Nome: ${funcionario.nome} ${funcionario.sobrenome}',
      );
      print(
        '   Matrícula: ${funcionario.matricula}',
      );
      print('');

      stdout.write(
        'Confirma a exclusão? (s/N): ',
      );
      String? confirmacao =
          await _readLineAsync();

      if (confirmacao == null ||
          ![
            's',
            'S',
            'sim',
            'SIM',
          ].contains(confirmacao.trim())) {
        print('❌ Exclusão cancelada!');
        await _aguardarTecla();
        return;
      }

      // O método de remoção espera a matrícula (não o id interno do DB)
      bool sucesso = await funcionarioService
          .excluir(funcionario.matricula);

      if (sucesso) {
        print(
          '\n✅ Funcionário excluído com sucesso!',
        );
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
      print('─' * 70);
      print('1. 📊 Logs Recentes');
      print('2. 📈 Relatório Diário');
      print('3. 📅 Relatório por Período');
      print('4. 👤 Logs por Funcionário');
      print(
        '5. 🗂️ Saídas IoT (mensagens operacionais)',
      );
      print('0. ⬅️  Voltar');
      print('─' * 70);

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
    print('─' * 70);

    try {
      List<LogEntry> logs = await logService
          .listarRecentes();

      if (logs.isEmpty) {
        print(
          '📭 Nenhum log encontrado no sistema.',
        );
      } else {
        print(
          'Total de registros: ${logs.length}',
        );
        print('');
        print(
          '┌────────────────────────────────────────────────────────────┐',
        );
        print(
          '│ Tipo  │ Data       │ Hora     │ Matrícula │ Nome do Funcionário │',
        );
        print(
          '├───────┼────────────┼──────────┼───────────┼──────────────────────┤',
        );

        for (LogEntry log in logs.take(20)) {
          String data =
              log.createdAt?.toString().substring(
                0,
                10,
              ) ??
              'N/A';
          String hora =
              log.createdAt?.toString().substring(
                11,
                19,
              ) ??
              'N/A';
          String tipo = log.tipo.toUpperCase();
          String matricula =
              (log.matricula ?? 'N/A');
          String nome =
              (log.nomeCompleto ?? 'N/A');

          // Mostrar tipo colorido
          String tipoColor = colorTipo(
            tipo.toLowerCase(),
          );
          print(
            '│ ${tipoColor.padRight(5 + (tipoColor.length - tipo.length))} │ ${data.padRight(10)} │ ${hora.padRight(8)} │ ${matricula.padRight(9)} │ ${nome.padRight(20)} │',
          );
        }

        print(
          '└────────────────────────────────────────────────────────────┘',
        );

        if (logs.length > 20) {
          print(
            '\n⚠️ Mostrando apenas os 20 registros mais recentes.',
          );
        }
      }
    } catch (e) {
      print('❌ Erro ao buscar logs: $e');
    }

    await _aguardarTecla();
  }

  Future<void> _mostrarSaidasIoT() async {
    _mostrarCabecalho();
    print(
      '🗂️ SAÍDAS OPERACIONAIS (IoT) - MODO AO VIVO',
    );
    print('─' * 70);

    if (saidaService == null) {
      print(
        '⚠️ Serviço de saídas não configurado.',
      );
      await _aguardarTecla();
      return;
    }

    try {
      // Mostrar buffer atual
      List<String> linhas = saidaService!.listar(
        limite: 200,
      );
      if (linhas.isEmpty) {
        print(
          '📭 Nenhuma saída registrada. Aguardando novas entradas...',
        );
      } else {
        print(
          'Mostrando ${linhas.length} linhas recentes:\n',
        );
        for (String l in linhas) {
          print(l);
        }
      }

      print(
        '\n⏱️  Sessão ao vivo: novas saídas aparecerão abaixo. Pressione ENTER para sair.',
      );

      // Assinar stream de novas saídas
      StreamSubscription<String>? saidaSub;
      StreamSubscription<String>? teclaSub;

      final completer = Completer<void>();

      saidaSub = saidaService!.stream.listen((
        novaLinha,
      ) {
        print(novaLinha);
      });

      // Escutar ENTER do usuário para sair (linha vazia ou 'q')
      teclaSub = _inputLines.listen((line) async {
        final t = line.trim().toLowerCase();
        if (t == '' || t == 'q') {
          await saidaSub?.cancel();
          await teclaSub?.cancel();
          completer.complete();
        }
      });

      // Aguardar até o usuário pressionar ENTER
      await completer.future;

      // Após encerrar, perguntar se quer limpar o buffer
      print(
        '\nDeseja limpar o buffer de saídas? (s/N)',
      );
      stdout.write('> ');
      String? resp = await _readLineAsync();
      if (resp != null &&
          resp.trim().toLowerCase() == 's') {
        saidaService!.limpar();
        print('✅ Buffer de saídas limpo.');
      }
    } catch (e) {
      print(
        '❌ Erro ao mostrar saídas em tempo real: $e',
      );
    }

    await _aguardarTecla();
  }

  Future<void> _relatorioDiario() async {
    _mostrarCabecalho();
    print('📈 RELATÓRIO DIÁRIO');
    print('─' * 70);

    try {
      DateTime hoje = DateTime.now();
      DateTime inicioHoje = DateTime(
        hoje.year,
        hoje.month,
        hoje.day,
      );
      DateTime fimHoje = inicioHoje.add(
        Duration(days: 1),
      );

      print(
        '📅 Data: ${inicioHoje.day.toString().padLeft(2, '0')}/${inicioHoje.month.toString().padLeft(2, '0')}/${inicioHoje.year}',
      );
      print('─' * 50);

      List<LogEntry> logs = await logService
          .listarPorPeriodo(inicioHoje, fimHoje);

      if (logs.isEmpty) {
        print(
          '📭 Nenhum registro encontrado para hoje.',
        );
      } else {
        print(
          '📊 Total de registros: ${logs.length}',
        );
        print('');

        // Agrupar por tipo de ação
        Map<String, int> acoesPorTipo = {};
        for (var log in logs) {
          acoesPorTipo[log.tipo] =
              (acoesPorTipo[log.tipo] ?? 0) + 1;
        }

        print('📋 Resumo por tipo de ação:');
        acoesPorTipo.forEach((tipo, quantidade) {
          String emoji = tipo == 'entrada'
              ? '🔓'
              : '🔒';
          print('   • $emoji $tipo: $quantidade');
        });

        print('\n🕐 Últimos 10 registros:');
        var ultimosLogs = logs.take(10);
        for (var log in ultimosLogs) {
          String data =
              log.createdAt?.toString().substring(
                0,
                10,
              ) ??
              'N/A';
          String hora =
              log.createdAt?.toString().substring(
                11,
                19,
              ) ??
              'N/A';
          String tipo = log.tipo.toUpperCase();
          String matricula =
              (log.matricula ?? 'N/A');
          String nome =
              (log.nomeCompleto ?? 'N/A');
          String tipoColor = colorTipo(
            tipo.toLowerCase(),
          );

          print(
            '   [$data $hora] $tipoColor - Mat: $matricula - $nome',
          );
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
    print('─' * 70);

    try {
      print('📅 Digite o período desejado:');
      print('');

      stdout.write('Data inicial (dd/mm/aaaa): ');
      String? dataInicialStr =
          await _readLineAsync();
      if (dataInicialStr == null ||
          dataInicialStr.trim().isEmpty) {
        print('❌ Data inicial é obrigatória!');
        await _aguardarTecla();
        return;
      }

      stdout.write('Data final (dd/mm/aaaa): ');
      String? dataFinalStr =
          await _readLineAsync();
      if (dataFinalStr == null ||
          dataFinalStr.trim().isEmpty) {
        print('❌ Data final é obrigatória!');
        await _aguardarTecla();
        return;
      }

      // Parsear datas
      List<String> partesInicial = dataInicialStr
          .split('/');
      List<String> partesFinal = dataFinalStr
          .split('/');

      if (partesInicial.length != 3 ||
          partesFinal.length != 3) {
        print(
          '❌ Formato de data inválido! Use dd/mm/aaaa',
        );
        await _aguardarTecla();
        return;
      }

      DateTime dataInicial = DateTime(
        int.parse(partesInicial[2]),
        int.parse(partesInicial[1]),
        int.parse(partesInicial[0]),
      );

      DateTime dataFinal = DateTime(
        int.parse(partesFinal[2]),
        int.parse(partesFinal[1]),
        int.parse(partesFinal[0]),
        23,
        59,
        59,
      );

      print(
        '\n🔍 Buscando logs de ${dataInicial.day.toString().padLeft(2, '0')}/${dataInicial.month.toString().padLeft(2, '0')}/${dataInicial.year} até ${dataFinal.day.toString().padLeft(2, '0')}/${dataFinal.month.toString().padLeft(2, '0')}/${dataFinal.year}...',
      );

      List<LogEntry> logs = await logService
          .listarPorPeriodo(
            dataInicial,
            dataFinal,
          );

      if (logs.isEmpty) {
        print(
          '📭 Nenhum registro encontrado no período especificado.',
        );
      } else {
        print(
          '📊 Total de registros: ${logs.length}',
        );
        print('');

        // Estatísticas
        Map<String, int> estatisticas = {};
        Map<String, List<LogEntry>>
        logsPorFuncionario = {};

        for (var log in logs) {
          estatisticas[log.tipo] =
              (estatisticas[log.tipo] ?? 0) + 1;

          String chave =
              '${log.matricula} - ${log.nomeCompleto ?? 'N/A'}';
          logsPorFuncionario[chave] =
              logsPorFuncionario[chave] ?? [];
          logsPorFuncionario[chave]!.add(log);
        }

        // Mostrar apenas a lista simplificada conforme solicitado
        print(
          '\n📋 Registros (Tipo, Data, Hora, Matrícula, Nome):',
        );
        for (var log in logs) {
          String data =
              log.createdAt?.toString().substring(
                0,
                10,
              ) ??
              'N/A';
          String hora =
              log.createdAt?.toString().substring(
                11,
                19,
              ) ??
              'N/A';
          String tipo = log.tipo.toUpperCase();
          String matricula =
              (log.matricula ?? 'N/A');
          String nome =
              (log.nomeCompleto ?? 'N/A');
          String tipoColor = colorTipo(
            tipo.toLowerCase(),
          );

          print(
            '   - $tipoColor, $data, $hora, $matricula, $nome',
          );
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
    print('─' * 70);

    try {
      stdout.write(
        'Digite a matrícula do funcionário: ',
      );
      String? matriculaStr =
          await _readLineAsync();
      if (matriculaStr == null ||
          matriculaStr.trim().isEmpty) {
        print('❌ Matrícula é obrigatória!');
        await _aguardarTecla();
        return;
      }

      int? matricula = int.tryParse(
        matriculaStr.trim(),
      );
      if (matricula == null) {
        print(
          '❌ Matrícula deve ser um número válido!',
        );
        await _aguardarTecla();
        return;
      }

      // Buscar funcionário para validar
      Funcionario? funcionario =
          await funcionarioService
              .buscarPorMatriculaUnica(matricula);
      if (funcionario == null) {
        print('❌ Funcionário não encontrado!');
        await _aguardarTecla();
        return;
      }

      print(
        '\n👤 Funcionário: ${funcionario.nome} ${funcionario.sobrenome}',
      );
      print('📊 Buscando registros...');

      List<LogEntry> logs = await logService
          .listarPorFuncionario(matricula);

      if (logs.isEmpty) {
        print(
          '📭 Nenhum registro encontrado para este funcionário.',
        );
      } else {
        print(
          '📋 Total de registros: ${logs.length}',
        );
        print('');

        // Estatísticas
        Map<String, int> estatisticas = {};
        for (var log in logs) {
          estatisticas[log.tipo] =
              (estatisticas[log.tipo] ?? 0) + 1;
        }

        // Mostrar apenas lista simples por funcionário
        print(
          '\n📋 Registros (Tipo, Data, Hora, Matrícula, Nome):',
        );
        var ultimosLogs = logs.take(15);
        for (var log in ultimosLogs) {
          String data =
              log.createdAt?.toString().substring(
                0,
                10,
              ) ??
              'N/A';
          String hora =
              log.createdAt?.toString().substring(
                11,
                19,
              ) ??
              'N/A';
          String tipo = log.tipo.toUpperCase();
          String matricula =
              (log.matricula ?? 'N/A');
          String nome =
              (log.nomeCompleto ?? 'N/A');
          String tipoColor = colorTipo(
            tipo.toLowerCase(),
          );

          print(
            '   - $tipoColor, $data, $hora, $matricula, $nome',
          );
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
      print('─' * 70);
      print('1. ❄️  Controlar Climatizador');
      print('2. 💡 Controlar Iluminação');
      print(
        '3. 🔄 Voltar ao Modo Automático (Climatizador + Iluminação)',
      );
      print('4. 🧪 Modo Teste');
      print('0. ⬅️  Voltar');
      print('─' * 70);

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
    print('─' * 70);

    try {
      EstadoClimatizador? estadoAtual =
          sistemaController.ultimoEstadoClima;

      if (estadoAtual != null) {
        print('📊 Estado Atual:');
        print(
          '   Status: ${estadoAtual.ligado ? "🟢 LIGADO" : "🔴 DESLIGADO"}',
        );
        print(
          '   Velocidade Ventilador: ${estadoAtual.velocidade}',
        );
        print(
          '   Umidificando: ${estadoAtual.umidificando ? "SIM" : "NÃO"}',
        );
        print('');
      }

      print('Opções:');
      print(
        '1. ${estadoAtual?.ligado == true ? "🔴 Desligar" : "🟢 Ligar"}',
      );
      print('2. 💨 Ajustar Ventilador');
      print('3. 🌀 Toggle Umidificação');
      print('0. ⬅️ Voltar');

      stdout.write('Escolha uma opção: ');
      String? opcao = await _readLineAsync();

      switch (opcao) {
        case '1':
          bool novoStatus =
              !(estadoAtual?.ligado ?? false);
          await firebaseService
              .enviarComandoClimatizador(
                novoStatus
                    ? 'ligar:1'
                    : 'desligar',
              );
          print(
            '✅ Climatizador ${novoStatus ? "ligado" : "desligado"}!',
          );
          break;

        case '2':
          stdout.write(
            'Velocidade do ventilador (0-3): ',
          );
          String? velStr = await _readLineAsync();
          int? novaVel = int.tryParse(
            velStr ?? '',
          );
          if (novaVel != null &&
              novaVel >= 0 &&
              novaVel <= 3) {
            await firebaseService
                .enviarComandoClimatizador(
                  'velocidade:$novaVel',
                );
            print(
              '✅ Ventilador ajustado para velocidade $novaVel!',
            );
          } else {
            print(
              '❌ Velocidade inválida (deve ser 0, 1, 2 ou 3)!',
            );
          }
          break;

        case '3':
          await firebaseService
              .enviarComandoClimatizador(
                'umidificador:toggle',
              );
          print('✅ Umidificador alternado!');
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
    print('─' * 70);

    try {
      stdout.write(
        'Intensidade da iluminação (0-100%): ',
      );
      String? intensidadeStr =
          await _readLineAsync();

      int? intensidade = int.tryParse(
        intensidadeStr ?? '',
      );
      if (intensidade != null &&
          intensidade >= 0 &&
          intensidade <= 100) {
        // Passar pelo controller para manter o estado interno consistente
        final ok = await sistemaController
            .definirIluminacaoManual(intensidade);
        if (ok) {
          print(
            '✅ Iluminação ajustada para $intensidade%!',
          );
        } else {
          print('❌ Falha ao ajustar iluminação.');
        }
      } else {
        print(
          '❌ Intensidade inválida (deve estar entre 0 e 100)!',
        );
      }
    } catch (e) {
      print('❌ Erro no controle: $e');
    }

    await _aguardarTecla();
  }

  Future<void> _resetarSistema() async {
    _mostrarCabecalho();
    print('🔄 VOLTAR AO MODO AUTOMÁTICO');
    print('─' * 70);
    stdout.write(
      '⚠️ Confirma que deseja retornar o climatizador ao modo AUTOMÁTICO? (s/N): ',
    );
    String? confirmacao = await _readLineAsync();

    if (confirmacao != null &&
        confirmacao.toLowerCase() == 's') {
      try {
        // Colocar climatizador em modo automático (estado interno) e publicar no Firebase para o ESP
        bool sucessoClimaInterno =
            await sistemaController
                .enviarComandoClimatizador(
                  'auto',
                );
        bool sucessoClimaFirebase = false;
        try {
          sucessoClimaFirebase =
              await firebaseService
                  .enviarComandoClimatizador(
                    'auto',
                  );
        } catch (_) {
          sucessoClimaFirebase = false;
        }

        // Colocar iluminação em modo automático (controller trata publicação no Firebase)
        bool sucessoIlum = await sistemaController
            .definirIluminacaoManual('auto');

        final sucessoClima =
            sucessoClimaInterno &&
            sucessoClimaFirebase;
        if (sucessoClima && sucessoIlum) {
          print(
            '✅ Climatizador e Iluminação retornaram ao modo AUTOMÁTICO com sucesso!',
          );

          // Forçar recalculo/publicação das preferências de grupo para que o ESP
          // aplique a automação imediatamente (por exemplo: atualizar relé da iluminação).
          try {
            await sistemaController
                .processarDadosSensores();
            print(
              '✅ Preferências recalculadas e publicadas para aplicação automática.',
            );
          } catch (e) {
            print(
              '⚠️ Falha ao recalcular/publicar preferências: $e',
            );
          }
          // Publicar nível de iluminação calculado diretamente em /comandos/iluminacao
          try {
            int nivelPublicar = 0;

            // Se houver leitura de sensores com número de pessoas, usar ela
            final dados = sistemaController
                .ultimaSensorData;
            if (dados != null) {
              if (dados.pessoas == 0) {
                nivelPublicar = 0;
              } else {
                // Tentar calcular preferências via controller (busca no MySQL/cache)
                PreferenciasGrupo?
                prefs = await sistemaController
                    .processarSolicitacaoPreferencias(
                      dados.tags,
                    );
                if (prefs != null) {
                  nivelPublicar =
                      prefs.luminosidadeUtilizada;
                } else {
                  // fallback: usar intensidade atual dos sensores ou 50
                  nivelPublicar =
                      dados.luminosidade > 0
                      ? dados.luminosidade
                      : 50;
                }
              }
            }

            await firebaseService
                .enviarComandoIluminacao(
                  nivelPublicar,
                );
            print(
              '✅ Publicado nível de iluminação desejado: $nivelPublicar%',
            );
          } catch (e) {
            print(
              '⚠️ Falha ao publicar nível de iluminação diretamente: $e',
            );
          }
        } else if (sucessoClima && !sucessoIlum) {
          print(
            '⚠️ Climatizador no modo AUTOMÁTICO, mas falha ao ajustar iluminação para AUTO.',
          );
        } else if (!sucessoClima && sucessoIlum) {
          print(
            '⚠️ Iluminação no modo AUTOMÁTICO, mas falha ao ajustar climatizador para AUTO.',
          );
        } else if (!sucessoClima &&
            !sucessoIlum) {
          print(
            '❌ Falha ao retornar ambos os sistemas para modo automático.',
          );
        } else if (!sucessoClima && sucessoIlum) {
          // cobertura redundante, mas clara
          print(
            '⚠️ Iluminação no modo AUTOMÁTICO, mas falha ao ajustar climatizador para AUTO.',
          );
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
    print('─' * 70);
    print(
      'Este modo permite testar a comunicação com os sistemas.',
    );
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
    print(
      '\n🔥 Testando conexão com Firebase...',
    );

    try {
      DadosSensores? dados = await firebaseService
          .lerSensores();
      if (dados != null) {
        print(
          '✅ Firebase conectado com sucesso!',
        );
        print('📊 Última leitura:');
        print(
          '   Temperatura: ${dados.temperatura}°C',
        );
        print('   Umidade: ${dados.humidade}%');
        print('   Luz: ${dados.luminosidade}%');
        print('   Pessoas: ${dados.pessoas}');
        print('   Tags: ${dados.tags}');
      } else {
        print(
          '⚠️ Firebase conectado, mas sem dados disponíveis.',
        );
      }
    } catch (e) {
      print('❌ Erro na conexão com Firebase: $e');
    }
  }

  Future<void> _testarBancoDados() async {
    print(
      '\n💾 Testando conexão com Banco de Dados...',
    );

    try {
      List<Funcionario> funcionarios =
          await funcionarioService.listarTodos();
      print(
        '✅ Banco de dados conectado com sucesso!',
      );
      print(
        '👥 Funcionários cadastrados: ${funcionarios.length}',
      );

      List<LogEntry> logs = await logService
          .listarRecentes();
      print('📝 Logs recentes: ${logs.length}');
    } catch (e) {
      print('❌ Erro na conexão com banco: $e');
    }
  }

  Future<void> _testarEsp32() async {
    print(
      '\n📡 Testando comunicação com ESP32...',
    );

    try {
      await firebaseService
          .enviarComandoClimatizador('ligar:1');
      print('✅ Comando enviado ao ESP32!');
      print(
        '   Teste: Ligar climatizador velocidade 1',
      );

      await Future.delayed(Duration(seconds: 2));

      await firebaseService
          .enviarComandoClimatizador('desligar');
      print('✅ Comando de desligar enviado!');
    } catch (e) {
      print(
        '❌ Erro na comunicação com ESP32: $e',
      );
    }
  }

  // Configurações removidas — menu simplificado conforme solicitação do usuário.

  void _sair() {
    _mostrarCabecalho();
    print('🚪 ENCERRANDO SISTEMA');
    print('─' * 70);
    print(
      'Obrigado por usar o Sistema IoT Packbag!',
    );
    print('Sistema encerrado com segurança.');
    _executando = false;
  }

  void _mostrarCabecalho() {
    // Limpar tela (multiplataforma)
    if (Platform.isWindows) {
      Process.runSync(
        'cls',
        [],
        runInShell: true,
      );
    } else {
      Process.runSync(
        'clear',
        [],
        runInShell: true,
      );
    }

    print(
      '╔════════════════════════════════════════════════════════════════════╗',
    );
    print(
      '║                    🏭 Sistema IoT Packbag v2.0                    ║',
    );
    print(
      '║                     Dashboard Console - Dart                       ║',
    );
    print(
      '╚════════════════════════════════════════════════════════════════════╝',
    );
    print('');
  }

  Future<void> _aguardarTecla() async {
    print(
      '\n⏎ Pressione ENTER para continuar...',
    );
    await _readLineAsync();
  }
}
