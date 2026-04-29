class SessionData {
  final String sessionId;
  final String fechaCreacion;
  final bool activa;
  final String tipoRegistro;
  final String fechaClase;
  final int parcial;

  SessionData({
    required this.sessionId,
    required this.fechaCreacion,
    required this.activa,
    required this.tipoRegistro,
    required this.fechaClase,
    required this.parcial,
  });

  Map<String, dynamic> toMap() => {
        'session_id': sessionId,
        'fecha_creacion': fechaCreacion,
        'activa': activa ? 1 : 0,
        'tipo_registro': tipoRegistro,
        'fecha_clase': fechaClase,
        'parcial': parcial,
      };

  factory SessionData.fromMap(Map<String, dynamic> map) {
    return SessionData(
      sessionId: (map['session_id'] ?? '').toString(),
      fechaCreacion: (map['fecha_creacion'] ?? '').toString(),
      activa: (map['activa'] ?? 0) == 1,
      tipoRegistro: (map['tipo_registro'] ?? '').toString(),
      fechaClase: (map['fecha_clase'] ?? '').toString(),
      parcial: map['parcial'] is int
          ? map['parcial']
          : int.tryParse((map['parcial'] ?? '1').toString()) ?? 1,
    );
  }
}