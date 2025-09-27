import 'utils.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';

void main() async {
  String mode = 'menu';

  void printMenu() {
    print('\x1B[2J\x1B[0;0H');
    print('================ DASHBOARD SENSORES ================');
    print(
      ' Leituras acumuladas: \x1B[36m\u001b[1m\u001b[4m\u001b[7m${leituras.length}\x1B[0m',
    );
    print('====================================================');
    print('Selecione uma opção:');
    print(' 1. Ver estatísticas de Temperatura');
    print(' 2. Ver estatísticas de Umidade');
    print(' 3. Ver estatísticas de Lux');
    print(' 4. Ver todas as estatísticas');
    print(' 0. Sair');
    stdout.write('\nDigite o número da opção desejada: ');
  }

  void mostrarEstatisticas(String escolha) {
    print('\x1B[2J\x1B[0;0H');
    print('================ DASHBOARD SENSORES ================');
    print(
      ' Leituras acumuladas: \x1B[36m\u001b[1m\u001b[4m\u001b[7m${leituras.length}\x1B[0m',
    );
    print('====================================================');
    var stats = obterEstatisticas();

    var ultima = leituras.isNotEmpty ? leituras.last : null;
    var atualTemp = ultima != null && ultima['temperatura'] != null
        ? ultima['temperatura']
        : 'N/A';
    var atualUmid = ultima != null && ultima['umidade'] != null
        ? ultima['umidade']
        : 'N/A';
    var atualLux = ultima != null && ultima['lux'] != null
        ? ultima['lux']
        : 'N/A';

    if (escolha == '1') {
      print('┌────────────────────────────────────┐');
      print('│     Estatísticas: Temperatura      │');
      print('├──────────────┬─────────┬───────────┤');
      print('│ Média (°C)   │   Min   │   Max     │');
      print('├──────────────┼─────────┼───────────┤');
      print(
        '│   \x1B[32m${stats['temperatura']!['media'].toString().padRight(9)}\x1B[0m  │ ${stats['temperatura']!['min'].toString().padRight(7)} │ ${stats['temperatura']!['max'].toString().padRight(9)} │',
      );
      print('└──────────────┴─────────┴───────────┘');
      print('\nLeitura atual: \x1B[31m${atualTemp}\x1B[0m °C');
    } else if (escolha == '2') {
      print('┌────────────────────────────────────┐');
      print('│        Estatísticas: Umidade       │');
      print('├──────────────┬─────────┬───────────┤');
      print('│ Média (%)    │   Min   │   Max     │');
      print('├──────────────┼─────────┼───────────┤');
      print(
        '│   \x1B[34m${stats['umidade']!['media'].toString().padRight(9)}\x1B[0m  │ ${stats['umidade']!['min'].toString().padRight(7)} │ ${stats['umidade']!['max'].toString().padRight(9)} │',
      );
      print('└──────────────┴─────────┴───────────┘');
      print('\nLeitura atual: \x1B[36m${atualUmid}\x1B[0m %');
    } else if (escolha == '3') {
      print('┌────────────────────────────────────┐');
      print('│          Estatísticas: Lux         │');
      print('├──────────────┬─────────┬───────────┤');
      print('│ Média (lx)   │   Min   │   Max     │');
      print('├──────────────┼─────────┼───────────┤');
      print(
        '│   \x1B[33m${stats['lux']!['media'].toString().padRight(9)}\x1B[0m  │ ${stats['lux']!['min'].toString().padRight(7)} │ ${stats['lux']!['max'].toString().padRight(9)} │',
      );
      print('└──────────────┴─────────┴───────────┘');
      print('\nLeitura atual: \x1B[33m${atualLux}\x1B[0m lx');
    } else if (escolha == '4') {
      print(
        '┌───────────────────────────────────────────────────────────────────┐',
      );
      print(
        '│ \x1B[1m\x1B[36m                      Estatísticas Consolidadas                  \x1B[0m │',
      );
      print(
        '├──────────────┬────────────┬─────────┬─────────┬──────────┬────────┤',
      );
      print(
        '│ \x1B[1mSensor       \x1B[0m│ \x1B[1mMédia      \x1B[0m│ \x1B[1mMin     \x1B[0m│ \x1B[1mMax     \x1B[0m│ \x1B[1mAtual   \x1B[0m │ \x1B[1mUnid. \x1B[0m │',
      );
      print(
        '├──────────────┼────────────┼─────────┼─────────┼──────────┼────────┤',
      );
      print(
        '│ \x1B[32mTemperatura  \x1B[0m│ \x1B[32m${stats['temperatura']!['media'].toString().padRight(10)}\x1B[0m │ ${stats['temperatura']!['min'].toString().padRight(7)} │ ${stats['temperatura']!['max'].toString().padRight(7)} │ \x1B[31m${atualTemp.toString().padRight(8)}\x1B[0m │ °C     │',
      );
      print(
        '│ \x1B[34mUmidade      \x1B[0m│ \x1B[34m${stats['umidade']!['media'].toString().padRight(10)}\x1B[0m │ ${stats['umidade']!['min'].toString().padRight(7)} │ ${stats['umidade']!['max'].toString().padRight(7)} │ \x1B[36m${atualUmid.toString().padRight(8)}\x1B[0m │ %      │',
      );
      print(
        '│ \x1B[33mLux          \x1B[0m│ \x1B[33m${stats['lux']!['media'].toString().padRight(10)}\x1B[0m │ ${stats['lux']!['min'].toString().padRight(7)} │ ${stats['lux']!['max'].toString().padRight(7)} │ \x1B[33m${atualLux.toString().padRight(8)}\x1B[0m │ lx     │',
      );
      print(
        '└──────────────┴────────────┴─────────┴─────────┴──────────┴────────┘',
      );
    }
  }

  void mostrarEstatisticasComMensagem(String escolha) {
    mostrarEstatisticas(escolha);
    print('\nAtualizando em tempo real. Pressione Enter para voltar ao menu.');
  }

  Timer timer = Timer.periodic(Duration(seconds: 2), (_) {
    adicionarLeitura();
    if (mode == 'menu') {
      printMenu();
    }
  });

  printMenu();

  var lines = stdin.transform(utf8.decoder).transform(const LineSplitter());
  Timer? statsTimer;
  String currentStatSensor = '';
  late StreamSubscription<String> subscription;

  subscription = lines.listen(
    (raw) {
      String escolha = raw.trim();

      if (mode == 'menu') {
        if (escolha == '0') {
          timer.cancel();
          statsTimer?.cancel();
          subscription.cancel();
          exit(0);
        } else if (['1', '2', '3', '4'].contains(escolha)) {
          currentStatSensor = escolha;
          mode = 'stats';
          statsTimer?.cancel();
          mostrarEstatisticasComMensagem(currentStatSensor);
          statsTimer = Timer.periodic(Duration(seconds: 1), (_) {
            mostrarEstatisticasComMensagem(currentStatSensor);
          });
        } else {
          print('\nOpção inválida! Tente novamente.');
          printMenu();
        }
      } else if (mode == 'stats') {
        statsTimer?.cancel();
        mode = 'menu';
        printMenu();
      }
    },
    onError: (e, st) {
      print('\nErro: $e');
      if (st != null) {
        print(st);
      }
      timer.cancel();
      statsTimer?.cancel();
      subscription.cancel();
    },
    onDone: () {
      timer.cancel();
      statsTimer?.cancel();
    },
  );
}
