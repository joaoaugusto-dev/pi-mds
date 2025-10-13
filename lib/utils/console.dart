// Funções utilitárias para saída colorida no console (ANSI)
const String _green = '\x1B[32m';
const String _red = '\x1B[31m';
const String _reset = '\x1B[0m';

/// Retorna o texto [label] envolvido com a cor apropriada baseada em [tipo].
/// Se [tipo] for 'entrada' usa verde, se 'saida' usa vermelho; caso contrário, não colore.
String colorLabelByTipo(String label, String tipo) {
  final t = tipo.toLowerCase();
  if (t == 'entrada') return '$_green$label$_reset';
  if (t == 'saida' || t == 'saída') return '$_red$label$_reset';
  return label;
}

/// Retorna o valor do tipo (uppercase) colorido.
String colorTipo(String tipo) => colorLabelByTipo(tipo.toUpperCase(), tipo);
