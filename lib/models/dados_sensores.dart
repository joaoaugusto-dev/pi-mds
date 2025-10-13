class DadosSensores {
  double temperatura;
  double humidade;
  int luminosidade;
  int pessoas;
  List<String> tags;
  DateTime timestamp;
  bool dadosValidos;

  DadosSensores({
    required this.temperatura,
    required this.humidade,
    required this.luminosidade,
    required this.pessoas,
    required this.tags,
    required this.timestamp,
    this.dadosValidos = true,
  });

  factory DadosSensores.fromJson(Map<String, dynamic> json) {
    return DadosSensores(
      temperatura: (json['temperatura'] as num?)?.toDouble() ?? 0.0,
      humidade: (json['humidade'] as num?)?.toDouble() ?? 0.0,
      luminosidade: json['luminosidade']?.toInt() ?? 0,
      pessoas: json['pessoas']?.toInt() ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'])
          : DateTime.now(),
      dadosValidos: json['dadosValidos'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperatura': temperatura,
      'humidade': humidade,
      'luminosidade': luminosidade,
      'pessoas': pessoas,
      'tags': tags,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'dadosValidos': dadosValidos,
    };
  }

  // Para salvar histórico no MySQL
  Map<String, dynamic> toHistoricoMap({
    bool? climaLigado,
    bool? climaUmidificando,
    int? climaVelocidade,
    bool? modoManualIlum,
    bool? modoManualClima,
  }) {
    return {
      'temperatura': temperatura,
      'humidade': humidade,
      'luminosidade': luminosidade,
      'pessoas': pessoas,
      'tags_presentes': tags.join(','),
      'clima_ligado': climaLigado ?? false,
      'clima_umidificando': climaUmidificando ?? false,
      'clima_velocidade': climaVelocidade ?? 0,
      'modo_manual_ilum': modoManualIlum ?? false,
      'modo_manual_clima': modoManualClima ?? false,
    };
  }

  @override
  String toString() {
    return 'Sensores: ${temperatura.toStringAsFixed(1)}°C, ${humidade.toStringAsFixed(1)}%, ${luminosidade}lux, ${pessoas}p, tags:[${tags.join(',')}]';
  }
}
