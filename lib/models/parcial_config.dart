class ParcialConfig {
  final int numero;
  final String fechaInicio;
  final String fechaFin;

  ParcialConfig({
    required this.numero,
    required this.fechaInicio,
    required this.fechaFin,
  });

  Map<String, dynamic> toMap() => {
        'numero': numero,
        'fecha_inicio': fechaInicio,
        'fecha_fin': fechaFin,
      };

  factory ParcialConfig.fromMap(Map<String, dynamic> map) {
    return ParcialConfig(
      numero: map['numero'] is int
          ? map['numero']
          : int.tryParse((map['numero'] ?? '1').toString()) ?? 1,
      fechaInicio: (map['fecha_inicio'] ?? '').toString(),
      fechaFin: (map['fecha_fin'] ?? '').toString(),
    );
  }
}