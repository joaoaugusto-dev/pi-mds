class DadosSensores {
  double temperatura;
  double humidade;
  int luminosidade;
  int ldr; // valor bruto do sensor LDR (ADC)
  int pessoas;
  List<String> tags;
  DateTime timestamp;
  bool dadosValidos;
  int iluminacaoArtificial; // Iluminação artificial (0, 25, 50, 75, 100)

  DadosSensores({
    required this.temperatura,
    required this.humidade,
    required this.luminosidade,
    required this.ldr,
    required this.pessoas,
    required this.tags,
    required this.timestamp,
    this.dadosValidos = true,
    this.iluminacaoArtificial = 0,
  });

  factory DadosSensores.fromJson(Map<String, dynamic> json) {
    return DadosSensores(
      temperatura: (json['temperatura'] as num?)?.toDouble() ?? 0.0,
      humidade: (json['humidade'] as num?)?.toDouble() ?? 0.0,
      luminosidade: json['luminosidade']?.toInt() ?? 0,
      ldr: json['ldr']?.toInt() ?? 0,
      pessoas: json['pessoas']?.toInt() ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'])
          : DateTime.now(),
      dadosValidos: json['dadosValidos'] ?? true,
      iluminacaoArtificial: json['iluminacao_artificial']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperatura': temperatura,
      'humidade': humidade,
      'luminosidade': luminosidade,
      'ldr': ldr,
      'pessoas': pessoas,
      'tags': tags,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'dadosValidos': dadosValidos,
      'iluminacao_artificial': iluminacaoArtificial,
    };
  }

  // Para salvar histórico no MySQL
  Map<String, dynamic> toHistoricoMap({
    bool? climaLigado,
    bool? climaUmidificando,
    int? climaVelocidade,
    bool? modoManualIlum,
    bool? modoManualClima,
    int? iluminacaoArtificial,
  }) {
    return {
      'temperatura': temperatura,
      'humidade': humidade,
      'luminosidade': luminosidade,
      'ldr': ldr,
      'pessoas': pessoas,
      'tags_presentes': tags.join(','),
      'clima_ligado': climaLigado ?? false,
      'clima_umidificando': climaUmidificando ?? false,
      'clima_velocidade': climaVelocidade ?? 0,
      'modo_manual_ilum': modoManualIlum ?? false,
      'modo_manual_clima': modoManualClima ?? false,
      'iluminacao_artificial':
          iluminacaoArtificial ?? this.iluminacaoArtificial,
    };
  }

  @override
  String toString() {
    return 'Sensores: ${temperatura.toStringAsFixed(1)}°C, ${humidade.toStringAsFixed(1)}%, luminosidade=$luminosidade%, ldr=$ldr, ${pessoas}p, tags:[${tags.join(',')}]';
  }
}
