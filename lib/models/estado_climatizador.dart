class EstadoClimatizador {
  bool ligado;
  bool umidificando;
  int velocidade;
  int ultimaVelocidade;
  int timer;
  bool aletaVertical;
  bool aletaHorizontal;
  DateTime? ultimaAtualizacao;
  String origem; // 'sistema', 'manual', 'ir'

  EstadoClimatizador({
    this.ligado = false,
    this.umidificando = false,
    this.velocidade = 0,
    this.ultimaVelocidade = 1,
    this.timer = 0,
    this.aletaVertical = false,
    this.aletaHorizontal = false,
    this.ultimaAtualizacao,
    this.origem = 'sistema',
  });

  factory EstadoClimatizador.fromJson(Map<String, dynamic> json) {
    return EstadoClimatizador(
      ligado: json['ligado'] ?? false,
      umidificando: json['umidificando'] ?? false,
      velocidade: json['velocidade']?.toInt() ?? 0,
      ultimaVelocidade: json['ultima_velocidade']?.toInt() ?? 1,
      timer: json['timer']?.toInt() ?? 0,
      aletaVertical: json['aleta_vertical'] ?? false,
      aletaHorizontal: json['aleta_horizontal'] ?? false,
      ultimaAtualizacao: json['ultima_atualizacao'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['ultima_atualizacao'])
          : null,
      origem: json['origem'] ?? 'sistema',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ligado': ligado,
      'umidificando': umidificando,
      'velocidade': velocidade,
      'ultima_velocidade': ultimaVelocidade,
      'timer': timer,
      'aleta_vertical': aletaVertical,
      'aleta_horizontal': aletaHorizontal,
      'ultima_atualizacao': ultimaAtualizacao?.millisecondsSinceEpoch,
      'origem': origem,
    };
  }

  bool get atualizado {
    if (ultimaAtualizacao == null) return false;
    return DateTime.now().difference(ultimaAtualizacao!).inMinutes < 1;
  }

  @override
  String toString() {
    String status = ligado ? 'LIGADO' : 'DESLIGADO';
    String extra = '';
    if (ligado) {
      extra = ' (vel: $velocidade';
      if (umidificando) extra += ', umid';
      if (aletaVertical) extra += ', av';
      if (aletaHorizontal) extra += ', ah';
      if (timer > 0) extra += ', timer: ${timer}h';
      extra += ')';
    }
    return 'Climatizador: $status$extra [$origem]';
  }
}
