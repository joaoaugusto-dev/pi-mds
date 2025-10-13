import '../dao/log_dao.dart';
import '../models/log_entry.dart';
import '../models/funcionario.dart';
import '../services/funcionario_service.dart';

class LogService {
  final LogDao logDao;
  final FuncionarioService funcionarioService;

  LogService(this.logDao, this.funcionarioService);

  // Processar mudanças nas tags (entrada/saída)
  Future<List<LogEntry>> processarMudancasTags(
    List<String> tagsAntigas,
    List<String> novasTags,
  ) async {
    List<LogEntry> logsGerados = [];

    // Detectar entradas (tags que estão agora mas não estavam antes)
    List<String> entradas = novasTags
        .where((tag) => !tagsAntigas.contains(tag))
        .toList();

    // Detectar saídas (tags que estavam antes mas não estão agora)
    List<String> saidas = tagsAntigas
        .where((tag) => !novasTags.contains(tag))
        .toList();

    // Processar entradas
    for (String tag in entradas) {
      LogEntry logEntry = await _criarLogEntrada(tag);
      await logDao.inserirLog(logEntry);
      logsGerados.add(logEntry);
    }

    // Processar saídas
    for (String tag in saidas) {
      LogEntry logEntry = await _criarLogSaida(tag);
      await logDao.inserirLog(logEntry);
      logsGerados.add(logEntry);
    }

    return logsGerados;
  }

  Future<LogEntry> _criarLogEntrada(String tag) async {
    Funcionario? funcionario = await funcionarioService.buscarPorTag(tag);

    if (funcionario != null) {
      return LogEntry(
        funcionarioId: funcionario.id,
        matricula: funcionario.matricula.toString(),
        nomeCompleto: funcionario.nomeCompleto,
        tipo: 'entrada',
        tagNfc: tag,
      );
    } else {
      return LogEntry(
        funcionarioId: null,
        matricula: null,
        nomeCompleto: 'TAG DESCONHECIDA',
        tipo: 'entrada',
        tagNfc: tag,
      );
    }
  }

  Future<LogEntry> _criarLogSaida(String tag) async {
    Funcionario? funcionario = await funcionarioService.buscarPorTag(tag);

    if (funcionario != null) {
      return LogEntry(
        funcionarioId: funcionario.id,
        matricula: funcionario.matricula.toString(),
        nomeCompleto: funcionario.nomeCompleto,
        tipo: 'saida',
        tagNfc: tag,
      );
    } else {
      return LogEntry(
        funcionarioId: null,
        matricula: null,
        nomeCompleto: 'TAG DESCONHECIDA',
        tipo: 'saida',
        tagNfc: tag,
      );
    }
  }

  // Listar logs recentes
  Future<List<LogEntry>> listarRecentes({int limit = 50}) async {
    return await logDao.listarLogs(limit: limit);
  }

  // Buscar logs por período de tempo
  Future<List<LogEntry>> buscarPorPeriodo(DateTime inicio, DateTime fim) async {
    return await logDao.buscarLogsPorPeriodo(inicio, fim);
  }

  // Buscar logs de um funcionário específico
  Future<List<LogEntry>> buscarPorFuncionario(int funcionarioId) async {
    return await logDao.buscarLogsPorFuncionario(funcionarioId);
  }

  // Estatísticas do dia atual
  Future<Map<String, int>> estatisticasHoje() async {
    return await logDao.estatisticasHoje();
  }

  // Obter logs de hoje
  Future<List<LogEntry>> logsHoje() async {
    DateTime hoje = DateTime.now();
    DateTime inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);
    DateTime fimHoje = inicioHoje.add(Duration(days: 1));

    return await buscarPorPeriodo(inicioHoje, fimHoje);
  }

  // Relatório resumido do dia
  Future<Map<String, dynamic>> relatorioHoje() async {
    Map<String, int> stats = await estatisticasHoje();
    List<LogEntry> logsHoje = await this.logsHoje();

    // Extrair pessoas únicas que entraram hoje
    Set<String> pessoasUnicas = {};
    for (LogEntry log in logsHoje) {
      if (log.tipo == 'entrada' && log.nomeCompleto != null) {
        pessoasUnicas.add(log.nomeCompleto!);
      }
    }

    return {
      'entradas': stats['entradas'] ?? 0,
      'saidas': stats['saidas'] ?? 0,
      'pessoas_unicas': pessoasUnicas.length,
      'total_logs': logsHoje.length,
      'logs_recentes': logsHoje.take(10).toList(),
    };
  }

  // Métodos adicionais para a interface
  Future<List<LogEntry>> listarPorPeriodo(DateTime inicio, DateTime fim) async {
    try {
      return await logDao.buscarLogsPorPeriodo(inicio, fim);
    } catch (e) {
      print('✗ Erro ao listar logs por período: $e');
      return [];
    }
  }

  Future<List<LogEntry>> listarPorFuncionario(int matricula) async {
    try {
      return await logDao.buscarLogsPorFuncionario(matricula);
    } catch (e) {
      print('✗ Erro ao listar logs por funcionário: $e');
      return [];
    }
  }

  Future<LogEntry?> obterUltimo() async {
    try {
      List<LogEntry> logs = await logDao.listarLogs(limit: 1);
      return logs.isNotEmpty ? logs.first : null;
    } catch (e) {
      print('✗ Erro ao obter último log: $e');
      return null;
    }
  }
}
