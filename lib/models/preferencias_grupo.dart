class PreferenciasGrupo {
  List<String> tagsPresentes;
  double? temperaturaMedia;
  double? luminosidadeMedia;
  int luminosidadeUtilizada;
  List<Map<String, dynamic>> funcionariosPresentes;
  List<String> tagsDesconhecidas;

  PreferenciasGrupo({
    required this.tagsPresentes,
    this.temperaturaMedia,
    this.luminosidadeMedia,
    this.luminosidadeUtilizada = 50,
    required this.funcionariosPresentes,
    required this.tagsDesconhecidas,
  });

  factory PreferenciasGrupo.fromJson(Map<String, dynamic> json) {
    return PreferenciasGrupo(
      tagsPresentes: List<String>.from(json['tags_presentes'] ?? []),
      temperaturaMedia: (json['temperatura_media'] as num?)?.toDouble(),
      luminosidadeMedia: (json['luminosidade_media'] as num?)?.toDouble(),
      luminosidadeUtilizada: json['luminosidade_utilizada']?.toInt() ?? 50,
      funcionariosPresentes: List<Map<String, dynamic>>.from(
        json['funcionarios_presentes'] ?? [],
      ),
      tagsDesconhecidas: List<String>.from(json['tags_desconhecidas'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tags_presentes': tagsPresentes,
      'temperatura_media': temperaturaMedia,
      'luminosidade_media': luminosidadeMedia,
      'luminosidade_utilizada': luminosidadeUtilizada,
      // Campos legados / compatíveis com firmware ESP32
      'temperatura_preferida': temperaturaMedia,
      'luminosidade_preferida': luminosidadeUtilizada,
      'funcionarios_presentes': funcionariosPresentes,
      'tags_desconhecidas': tagsDesconhecidas,
    };
  }

  bool get temFuncionariosCadastrados => funcionariosPresentes.isNotEmpty;
  bool get temTagsDesconhecidas => tagsDesconhecidas.isNotEmpty;
  int get totalPessoas =>
      funcionariosPresentes.length + tagsDesconhecidas.length;

  @override
  String toString() {
    return 'Grupo: ${totalPessoas}p ($funcionariosPresentes.length conhecidos), Temp: ${temperaturaMedia?.toStringAsFixed(1) ?? 'N/A'}°C, Lumi: $luminosidadeUtilizada%';
  }
}
