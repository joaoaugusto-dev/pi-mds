
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/firebase_config.dart';
import '../models/dados_sensores.dart';
import '../models/estado_climatizador.dart';
import 'saida_service.dart';


class FirebaseService {
  final String baseUrl;
  final String authToken;
  final SaidaService? _saidaService;

  FirebaseService({
    this.baseUrl = FirebaseConfig.baseUrl,
    this.authToken = FirebaseConfig.authToken,
    SaidaService? saidaService,
  }) : _saidaService = saidaService;

  String _buildUrl(String path) {
    String p = path.startsWith('/')
        ? path.substring(1)
        : path;
    String url =
        '${baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'}$p.json';
    if (authToken.isNotEmpty) {
      url += '?auth=$authToken';
    }
    return url;
  }

  Future<DadosSensores?> lerSensores() async {
    try {
      final url = Uri.parse(
        _buildUrl(FirebaseConfig.sensoresPath),
      );
      final response = await http.get(url);

      if (response.statusCode == 200 &&
          response.body != 'null') {
        final Map<String, dynamic> data =
            jsonDecode(response.body);
        return DadosSensores.fromJson(data);
      }
    } catch (e) {
      print(
        '✗ Erro ao ler sensores Firebase: $e',
      );
    }
    return null;
  }

  Future<EstadoClimatizador?>
  lerClimatizador() async {
    try {
      final url = Uri.parse(
        _buildUrl(
          FirebaseConfig.climatizadorPath,
        ),
      );
      final response = await http.get(url);

      if (response.statusCode == 200 &&
          response.body != 'null') {
        final Map<String, dynamic> data =
            jsonDecode(response.body);
        return EstadoClimatizador.fromJson(data);
      }
    } catch (e) {
      print(
        '✗ Erro ao ler climatizador Firebase: $e',
      );
    }
    return null;
  }

  Future<bool> enviarComandoIluminacao(
    dynamic comando,
  ) async {
    try {
      String comandoStr = comando.toString();
      if (comandoStr != 'auto' &&
          ![
            '0',
            '25',
            '50',
            '75',
            '100',
          ].contains(comandoStr)) {
        print(
          '✗ Comando iluminação inválido: $comando',
        );
        return false;
      }

      final url = Uri.parse(
        _buildUrl(
          '${FirebaseConfig.comandosPath}/iluminacao',
        ),
      );
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'comando': comando,
          'timestamp': DateTime.now()
              .millisecondsSinceEpoch,
          'origem': 'app',
        }),
      );

      if (response.statusCode == 200) {
        final msg =
            '✓ Comando iluminação enviado: $comando';
        if (_saidaService != null) {
          _saidaService.adicionar(msg);
        } else {
          print(msg);
        }
        return true;
      }
    } catch (e) {
      print(
        '✗ Erro ao enviar comando iluminação: $e',
      );
    }
    return false;
  }

  Future<bool> enviarComandoClimatizador(
    String comando, {
    int? velocidade,
  }) async {
    try {
      final comandosValidos = [
        'auto',
        'power',
        'power_on',
        'power_off',
        'velocidade',
        'umidificar',
        'timer',
        'aleta_v',
        'aleta_h',
      ];

      if (!comandosValidos.contains(comando)) {
        print(
          '✗ Comando climatizador inválido: $comando',
        );
        return false;
      }

      final url = Uri.parse(
        _buildUrl(
          '${FirebaseConfig.comandosPath}/climatizador',
        ),
      );

      Map<String, dynamic> payload = {
        'comando': comando,
        'timestamp':
            DateTime.now().millisecondsSinceEpoch,
        'origem': 'app',
      };

      if (velocidade != null &&
          (comando == 'velocidade' ||
              comando == 'power_on' ||
              comando == 'power')) {
        if (velocidade >= 1 && velocidade <= 3) {
          payload['velocidade'] = velocidade;
          print(
            '✓ Velocidade especificada: $velocidade',
          );
        } else {
          print(
            '⚠ Velocidade inválida ignorada: $velocidade (deve ser 1-3)',
          );
        }
      }

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final msg =
            '✓ Comando climatizador enviado: $comando${velocidade != null ? ' (vel: $velocidade)' : ''}';
        if (_saidaService != null) {
          _saidaService.adicionar(msg);
        } else {
          print(msg);
        }
        return true;
      }
    } catch (e) {
      print(
        '✗ Erro ao enviar comando climatizador: $e',
      );
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> lerLogs({
    int limit = 50,
  }) async {
    try {
      final url = Uri.parse(
        _buildUrl(FirebaseConfig.logsPath),
      );
      final response = await http.get(url);

      if (response.statusCode == 200 &&
          response.body != 'null') {
        final Map<String, dynamic> data =
            jsonDecode(response.body);
        List<Map<String, dynamic>> logs = [];

        data.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            logs.add({...value, 'id': key});
          }
        });

        logs.sort((a, b) {
          int timestampA = a['timestamp'] ?? 0;
          int timestampB = b['timestamp'] ?? 0;
          return timestampB.compareTo(timestampA);
        });

        return logs.take(limit).toList();
      }
    } catch (e) {
      print('✗ Erro ao ler logs Firebase: $e');
    }
    return [];
  }

  Future<bool> escreverLog(
    Map<String, dynamic> logData,
  ) async {
    try {
      final url = Uri.parse(
        _buildUrl(FirebaseConfig.logsPath),
      );
      logData['timestamp'] =
          DateTime.now().millisecondsSinceEpoch;

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(logData),
      );

      return response.statusCode == 200;
    } catch (e) {
      print(
        '✗ Erro ao escrever log Firebase: $e',
      );
      return false;
    }
  }

  Future<bool> limparComando(
    String caminho,
  ) async {
    try {
      final url = Uri.parse(_buildUrl(caminho));
      final response = await http.delete(url);
      return response.statusCode == 200;
    } catch (e) {
      print('✗ Erro ao limpar comando: $e');
      return false;
    }
  }

  Future<String?> lerUltimaTag() async {
    try {
      final url = Uri.parse(
        _buildUrl(FirebaseConfig.ultimaTagPath),
      );
      final response = await http.get(url);

      if (response.statusCode == 200 &&
          response.body != 'null') {
        String body = response.body;
        body = body.replaceAll('"', '');
        return body.trim();
      }
    } catch (e) {
      print(
        '✗ Erro ao ler ultima tag Firebase: $e',
      );
    }
    return null;
  }

  Future<bool> limparUltimaTag() async {
    try {
      final url = Uri.parse(
        _buildUrl(FirebaseConfig.ultimaTagPath),
      );
      final response = await http.delete(url);
      return response.statusCode == 200;
    } catch (e) {
      print('✗ Erro ao limpar ultima tag: $e');
      return false;
    }
  }

  Future<bool> setModoCadastro(bool ativo) async {
    try {
      final url = Uri.parse(
        _buildUrl('/modo_cadastro'),
      );
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(ativo),
      );

      if (response.statusCode == 200) {
        final msg =
            '✓ Modo cadastro setado: $ativo';
        if (_saidaService != null) {
          _saidaService.adicionar(msg);
        } else {
          print(msg);
        }
        return true;
      }
    } catch (e) {
      print('✗ Erro ao setar modo cadastro: $e');
    }
    return false;
  }

  Stream<DadosSensores?> streamSensores({
    Duration interval = const Duration(
      seconds: 2,
    ),
  }) async* {
    while (true) {
      yield await lerSensores();
      await Future.delayed(interval);
    }
  }

  Stream<EstadoClimatizador?> streamClimatizador({
    Duration interval = const Duration(
      seconds: 3,
    ),
  }) async* {
    while (true) {
      yield await lerClimatizador();
      await Future.delayed(interval);
    }
  }

  Future<String?> lerPreferenciasRequest() async {
    try {
      final url = Uri.parse(
        _buildUrl('/preferencias_request'),
      );
      final response = await http.get(url);

      if (response.statusCode == 200 &&
          response.body != 'null') {
        return response.body;
      }
    } catch (e) {
      print(
        '✗ Erro ao ler preferencias_request Firebase: $e',
      );
    }
    return null;
  }

  Future<bool> limparPreferenciasRequest() async {
    try {
      final url = Uri.parse(
        _buildUrl('/preferencias_request'),
      );
      final response = await http.delete(url);
      return response.statusCode == 200;
    } catch (e) {
      print(
        '✗ Erro ao limpar preferencias_request: $e',
      );
      return false;
    }
  }

  Future<bool> salvarPreferenciasGrupo(
    Map<String, dynamic> preferencias,
  ) async {
    try {
      final urlStr = _buildUrl(
        FirebaseConfig.preferenciasGrupoPath,
      );
      final url = Uri.parse(urlStr);
      final body = jsonEncode(preferencias);
      final msgEnviar =
          '⚠ Enviando preferencias_grupo para Firebase: $urlStr';
      final msgPayload = '⚠ Payload: $body';
      if (_saidaService != null) {
        _saidaService.adicionar(msgEnviar);
        _saidaService.adicionar(msgPayload);
      } else {
        print(msgEnviar);
        print(msgPayload);
      }

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      );

      final msgResp =
          '✓ Resposta Firebase (preferencias_grupo): HTTP ${response.statusCode} - ${response.body}';
      if (_saidaService != null) {
        _saidaService.adicionar(msgResp);
      } else {
        print(msgResp);
      }

      return response.statusCode == 200 ||
          response.statusCode == 204;
    } catch (e) {
      final msgErr =
          '✗ Erro ao salvar preferências grupo no Firebase: $e';
      if (_saidaService != null) {
        _saidaService.adicionar(msgErr);
      } else {
        print(msgErr);
      }
      return false;
    }
  }

  
}
