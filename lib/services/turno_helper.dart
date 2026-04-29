class TurnoHelper {
  static String nombreTurno(String turno) {
    switch (turno.trim()) {
      case '1':
        return 'Matutino';
      case '2':
        return 'Vespertino';
      case '4':
        return 'Sabatino';
      default:
        return 'Desconocido';
    }
  }

  static String nombreModalidad(String modalidad) {
    switch (modalidad.trim().toUpperCase()) {
      case 'E':
        return 'Escolarizado';
      case 'S':
        return 'Semiescolarizado';
      default:
        return 'Desconocido';
    }
  }

  static String grupoCompleto({
    required String semestre,
    required String grupo,
  }) {
    return '$semestre° $grupo';
  }
}