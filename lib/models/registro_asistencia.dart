class RegistroAsistencia {
  final String idRegistro;
  final String sessionId;
  final String plantel;
  final String nombre;
  final String matricula;
  final String semestre;
  final String grupo;
  final String turno;
  final String modalidad;
  final String curp;
  final String materiaClave;
  final String materiaNombre;
  final String tipoRegistro;
  final String fechaClase;
  final String fechaHoraEscaneo;
  final String codigo;
  final int parcial;

  final int docenteId;
  final bool sincronizado;
  final String fechaSincronizacion;

  RegistroAsistencia({
    required this.idRegistro,
    required this.sessionId,
    required this.plantel,
    required this.nombre,
    required this.matricula,
    required this.semestre,
    required this.grupo,
    required this.turno,
    required this.modalidad,
    required this.curp,
    required this.materiaClave,
    required this.materiaNombre,
    required this.tipoRegistro,
    required this.fechaClase,
    required this.fechaHoraEscaneo,
    required this.codigo,
    required this.parcial,
    this.docenteId = 0,
    this.sincronizado = false,
    this.fechaSincronizacion = '',
  });

  Map<String, dynamic> toMap() => {
        'id_registro': idRegistro,
        'session_id': sessionId,
        'plantel': plantel,
        'nombre': nombre,
        'matricula': matricula,
        'semestre': semestre,
        'grupo': grupo,
        'turno': turno,
        'modalidad': modalidad,
        'curp': curp,
        'materia_clave': materiaClave,
        'materia_nombre': materiaNombre,
        'tipo_registro': tipoRegistro,
        'fecha_clase': fechaClase,
        'fecha_hora_escaneo': fechaHoraEscaneo,
        'codigo': codigo,
        'parcial': parcial,
        'docente_id': docenteId,
        'sincronizado': sincronizado ? 1 : 0,
        'fecha_sincronizacion': fechaSincronizacion,
      };

  factory RegistroAsistencia.fromMap(Map<String, dynamic> map) {
    return RegistroAsistencia(
      idRegistro: (map['id_registro'] ?? '').toString(),
      sessionId: (map['session_id'] ?? '').toString(),
      plantel: (map['plantel'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      matricula: (map['matricula'] ?? '').toString(),
      semestre: (map['semestre'] ?? '').toString(),
      grupo: (map['grupo'] ?? '').toString(),
      turno: (map['turno'] ?? '').toString(),
      modalidad: (map['modalidad'] ?? '').toString(),
      curp: (map['curp'] ?? '').toString(),
      materiaClave: (map['materia_clave'] ?? '').toString(),
      materiaNombre: (map['materia_nombre'] ?? '').toString(),
      tipoRegistro: (map['tipo_registro'] ?? '').toString(),
      fechaClase: (map['fecha_clase'] ?? '').toString(),
      fechaHoraEscaneo: (map['fecha_hora_escaneo'] ?? '').toString(),
      codigo: (map['codigo'] ?? '').toString(),
      parcial: map['parcial'] is int
          ? map['parcial']
          : int.tryParse((map['parcial'] ?? '1').toString()) ?? 1,
      docenteId: map['docente_id'] is int
          ? map['docente_id'] as int
          : int.tryParse((map['docente_id'] ?? '0').toString()) ?? 0,
      sincronizado: (map['sincronizado'] ?? 0) == 1,
      fechaSincronizacion: (map['fecha_sincronizacion'] ?? '').toString(),
    );
  }
}