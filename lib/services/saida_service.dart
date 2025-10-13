import 'dart:async';
import 'dart:collection';

/// Serviço simples para armazenar em memória linhas de saída/notifications
/// que não devem poluir o fluxo principal do console. Usado para separar
/// mensagens de operação (por exemplo, comandos enviados ao ESP, cálculos
/// de preferências) da interação do usuário com o dashboard.
class SaidaService {
  // buffer com capacidade limitada
  final int _capacidade;
  final Queue<String> _buffer = Queue<String>();

  // Controller broadcast para permitir assinaturas em tempo real
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  SaidaService({int capacidade = 200}) : _capacidade = capacidade;

  void adicionar(String linha) {
    final entry = '${DateTime.now().toIso8601String()} - $linha';
    if (_buffer.length >= _capacidade) {
      _buffer.removeFirst();
    }
    _buffer.addLast(entry);
    // Notificar assinantes em tempo real
    try {
      _controller.add(entry);
    } catch (_) {
      // Se não houver assinantes, ignorar
    }
  }

  /// Stream broadcast com as linhas adicionadas
  Stream<String> get stream => _controller.stream;

  /// Retorna as linhas mais recentes (até [limite]), em ordem cronológica
  List<String> listar({int limite = 100}) {
    final items = _buffer.toList();
    if (limite <= 0 || items.length <= limite) return items;
    return items.sublist(items.length - limite);
  }

  /// Limpa o buffer
  void limpar() {
    _buffer.clear();
  }

  /// Fecha o controller (opcional, não obrigatório para uso durante a vida do app)
  Future<void> dispose() async {
    await _controller.close();
  }
}
