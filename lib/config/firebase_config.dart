class FirebaseConfig {
  static const String baseUrl =
      'https://projeto-pi-mds-default-rtdb.firebaseio.com/';
  static const String authToken = ''; // Token de autenticação se necessário

  // Paths específicos do Firebase
  static const String sensoresPath = '/sensores';
  static const String funcionariosPath = '/funcionarios';
  static const String comandosPath = '/comandos';
  static const String climatizadorPath = '/climatizador';
  static const String iluminacaoPath = '/iluminacao';
  static const String logsPath = '/logs';
  static const String preferenciasPorTagPath = '/preferencias_por_tag';
  static const String preferenciasGrupoPath = '/preferencias_grupo';
  // Última tag lida pelo ESP (campo usado para cadastro via aproximação)
  static const String ultimaTagPath = '/ultima_tag';
}
