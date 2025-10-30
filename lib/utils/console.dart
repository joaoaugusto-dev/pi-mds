const String _green = '\x1B[32m';
const String _red = '\x1B[31m';
const String _reset = '\x1B[0m';

String colorLabelByTipo(String label, String tipo) {
  final t = tipo.toLowerCase();
  if (t == 'entrada') return '$_green$label$_reset';
  if (t == 'saida' || t == 'saída') return '$_red$label$_reset';
  return label;
}

String colorTipo(String tipo) =>
    colorLabelByTipo(tipo.toUpperCase(), tipo);
