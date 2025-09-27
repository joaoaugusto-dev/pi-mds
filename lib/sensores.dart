import 'dart:math';

Map<String, dynamic> gerarLeitura() {
  final random = Random();

  double sensorTemp = (20 + random.nextDouble() * 15);
  sensorTemp = double.parse(sensorTemp.toStringAsFixed(1));
  int sensorUmid = (40 + random.nextDouble() * 40).round();
  int sensorLdr = random.nextInt(1001);
  String dataHora = DateTime.now().toString();

  return {
    'dataHora': dataHora,
    'temperatura': sensorTemp,
    'umidade': sensorUmid,
    'lux': sensorLdr,
  };
}
