class Materia {
  final String clave;     // se guarda, no se muestra
  final String nombre;    // se muestra
  final String semestre;  // se muestra
  final String plan;      // se muestra

  const Materia({
    required this.clave,
    required this.nombre,
    required this.semestre,
    required this.plan,
  });

  String get etiqueta =>
      '$nombre · $semestre° semestre · Plan $plan';

  Map<String, dynamic> toMap() => {
        'clave': clave,
        'nombre': nombre,
        'semestre': semestre,
        'plan': plan,
      };

  factory Materia.fromMap(Map<String, dynamic> map) {
    return Materia(
      clave: (map['clave'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      semestre: (map['semestre'] ?? '').toString(),
      plan: (map['plan'] ?? '').toString(),
    );
  }
}