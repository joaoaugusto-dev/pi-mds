class PreferenciaTag {
  String tag;
  double temperaturaPreferida;
  int luminosidadePreferida;
  DateTime? ultimaAtualizacao;
  String nomeCompleto;

  PreferenciaTag({
    required this.tag,
    this.temperaturaPreferida = 25.0,
    this.luminosidadePreferida = 50,
    this.ultimaAtualizacao,
    this.nomeCompleto = '',
  });

  factory PreferenciaTag.fromJson(Map<String, dynamic> json) {
    return PreferenciaTag(
      tag: json['tag'] ?? '',
      temperaturaPreferida:
          (json['temperatura_preferida'] as num?)?.toDouble() ?? 25.0,
      luminosidadePreferida: json['luminosidade_preferida']?.toInt() ?? 50,
      ultimaAtualizacao: json['ultima_atualizacao'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['ultima_atualizacao'])
          : null,
      nomeCompleto: json['nome_completo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tag': tag,
      'temperatura_preferida': temperaturaPreferida,
      'luminosidade_preferida': luminosidadePreferida,
      'ultima_atualizacao':
          ultimaAtualizacao?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      'nome_completo': nomeCompleto,
    };
  }

  @override
  String toString() {
    return 'Preferência $tag: ${temperaturaPreferida.toStringAsFixed(1)}°C, ${luminosidadePreferida}% luz';
  }
}
