import 'dart:async';
import 'dart:collection';
class SaidaService {
  final int _capacidade;
  final Queue<String> _buffer = Queue<String>();

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  SaidaService({int capacidade = 200}) : _capacidade = capacidade;

  void adicionar(String linha) {
    final entry = '${DateTime.now().toIso8601String()} - $linha';
    if (_buffer.length >= _capacidade) {
      _buffer.removeFirst();
    }
    _buffer.addLast(entry);
    try {
      _controller.add(entry);
    } catch (_) {
    }
  }

  Stream<String> get stream => _controller.stream;

  List<String> listar({int limite = 100}) {
    final items = _buffer.toList();
    if (limite <= 0 || items.length <= limite) return items;
    return items.sublist(items.length - limite);
  }

  void limpar() {
    _buffer.clear();
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
