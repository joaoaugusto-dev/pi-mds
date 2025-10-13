class Funcionario {
  int? id;
  int matricula;
  String nome;
  String sobrenome;
  String senha;
  double tempPreferida;
  int lumiPreferida;
  String? tagNfc;
  DateTime? createdAt;
  DateTime? updatedAt;

  Funcionario({
    this.id,
    required this.matricula,
    required this.nome,
    required this.sobrenome,
    required this.senha,
    this.tempPreferida = 24.0,
    this.lumiPreferida = 75,
    this.tagNfc,
    this.createdAt,
    this.updatedAt,
  });

  // Construtor para criar a partir do banco de dados
  factory Funcionario.fromMap(Map<String, dynamic> map) {
    return Funcionario(
      id: map['id'],
      matricula: map['matricula'],
      nome: map['nome'],
      sobrenome: map['sobrenome'],
      senha: map['senha'],
      tempPreferida: (map['temp_preferida'] as num?)?.toDouble() ?? 24.0,
      lumiPreferida: map['lumi_preferida'] ?? 75,
      tagNfc: map['tag_nfc'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'].toString())
          : null,
    );
  }

  // Converter para Map para insert/update
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matricula': matricula,
      'nome': nome,
      'sobrenome': sobrenome,
      'senha': senha,
      'temp_preferida': tempPreferida,
      'lumi_preferida': lumiPreferida,
      'tag_nfc': tagNfc,
    };
  }

  String get nomeCompleto => '$nome $sobrenome';

  @override
  String toString() {
    return 'Funcionario{id: $id, matricula: $matricula, nome: $nomeCompleto, temp: $tempPreferida°C, lumi: $lumiPreferida%, tag: $tagNfc}';
  }
}
