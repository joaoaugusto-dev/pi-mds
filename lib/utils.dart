import 'package:pi_mds/sensores.dart';

//lista global para armazenar as leituras
List<Map<String, dynamic>> leituras = [];

//adiciona leitura à uma lista global
void adicionarLeitura() {
  leituras.add(gerarLeitura());
}

//separa os dados gerados no sensor.dart
List<double> getTemperaturas() =>
    leituras.map((l) => l['temperatura'] as double).toList();
List<double> getUmidades() =>
    leituras.map((l) => (l['umidade'] as num).toDouble()).toList();
List<double> getLux() =>
    leituras.map((l) => (l['lux'] as num).toDouble()).toList();

// calcular média
double calcularMedia(List<double> valores, {int casasDecimais = 1}) {
  if (valores.isEmpty) return 0;
  double soma = 0;
  for (var v in valores) {
    soma += v;
  }
  double media = soma / valores.length;
  return double.parse(media.toStringAsFixed(casasDecimais));
}

// calcular mínimo
double calcularMin(List<double> valores, {int casasDecimais = 1}) {
  if (valores.isEmpty) return 0;
  double min = valores.first;
  for (var v in valores) {
    if (v < min) {
      min = v;
    }
  }
  return double.parse(min.toStringAsFixed(casasDecimais));
}

// calcular máximo
double calcularMax(List<double> valores, {int casasDecimais = 1}) {
  if (valores.isEmpty) return 0;
  double max = valores.first;
  for (var v in valores) {
    if (v > max) {
      max = v;
    }
  }
  return double.parse(max.toStringAsFixed(casasDecimais));
}

//acumulando as estatísticas
Map<String, Map<String, double>> obterEstatisticas() {
  return {
    'temperatura': {
      'media': calcularMedia(getTemperaturas(), casasDecimais: 1),
      'min': calcularMin(getTemperaturas(), casasDecimais: 1),
      'max': calcularMax(getTemperaturas(), casasDecimais: 1),
    },
    'umidade': {
      'media': calcularMedia(getUmidades(), casasDecimais: 1),
      'min': calcularMin(getUmidades(), casasDecimais: 1),
      'max': calcularMax(getUmidades(), casasDecimais: 1),
    },
    'lux': {
      'media': calcularMedia(getLux(), casasDecimais: 1),
      'min': calcularMin(getLux(), casasDecimais: 1),
      'max': calcularMax(getLux(), casasDecimais: 1),
    },
  };
}
