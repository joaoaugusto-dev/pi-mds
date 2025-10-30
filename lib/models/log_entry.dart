import '../utils/console.dart';

class LogEntry {
  int? id;
  int? funcionarioId;
  String? matricula;
  String? nomeCompleto;
  String tipo;
  String? tagNfc;
  DateTime? createdAt;
  DateTime? updatedAt;

  LogEntry({
    this.id,
    this.funcionarioId,
    this.matricula,
    this.nomeCompleto,
    required this.tipo,
    this.tagNfc,
    this.createdAt,
    this.updatedAt,
  });

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'],
      funcionarioId: map['funcionario_id'],
      matricula: map['matricula'],
      nomeCompleto: map['nome_completo'],
      tipo: map['tipo'],
      tagNfc: map['tag_nfc'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'funcionario_id': funcionarioId,
      'matricula': matricula,
      'nome_completo': nomeCompleto,
      'tipo': tipo,
      'tag_nfc': tagNfc,
    };
  }

  @override
  String toString() {
    final tipoColor = colorTipo(tipo);
    return 'LogEntry{$tipoColor: $nomeCompleto (${matricula ?? tagNfc}) - ${createdAt?.toString().substring(0, 19) ?? 'N/A'}}';
  }
}
