import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/materia.dart';

class MateriasService {
  static const String _assetPath = 'assets/data/materias_2026.json';

  static Future<List<Materia>> obtenerCatalogo() async {
    final jsonString = await rootBundle.loadString(_assetPath);
    final data = json.decode(jsonString) as List<dynamic>;

    final materias = data
        .map((item) => Materia.fromMap(Map<String, dynamic>.from(item as Map)))
        .where((m) => m.clave.isNotEmpty && m.nombre.isNotEmpty)
        .toList();

    materias.sort((a, b) {
      final semestreA = int.tryParse(a.semestre) ?? 99;
      final semestreB = int.tryParse(b.semestre) ?? 99;
      final cmpSemestre = semestreA.compareTo(semestreB);
      if (cmpSemestre != 0) return cmpSemestre;
      return a.nombre.compareTo(b.nombre);
    });

    return materias;
  }
}
