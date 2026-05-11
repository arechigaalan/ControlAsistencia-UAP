import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/materia.dart';
import 'local_storage.dart';

class MateriasService {
  static const String _assetPath = 'assets/data/materias_2026.json';

  static Future<List<Materia>> obtenerCatalogo() async {
    await sincronizarCatalogoSiCambio();
    return LocalStorage.obtenerCatalogoMaterias();
  }

  static Future<void> sincronizarCatalogoSiCambio() async {
    final jsonString = await rootBundle.loadString(_assetPath);
    final decoded = json.decode(jsonString);

    final int versionJson;
    final List<dynamic> data;

    if (decoded is Map<String, dynamic>) {
      versionJson = int.tryParse((decoded['version'] ?? '1').toString()) ?? 1;
      data = decoded['materias'] as List<dynamic>;
    } else {
      // Compatibilidad con tu JSON viejo tipo lista.
      versionJson = 1;
      data = decoded as List<dynamic>;
    }

    final versionDb = await LocalStorage.obtenerVersionCatalogoMaterias();
    final existeCatalogo = await LocalStorage.catalogoMateriasExiste();

    if (existeCatalogo && versionDb == versionJson) return;

    final materias = data
        .map((item) => Materia.fromMap(Map<String, dynamic>.from(item as Map)))
        .where((m) => m.clave.isNotEmpty && m.nombre.isNotEmpty)
        .toList();

    materias.sort((a, b) {
      final semestreA = int.tryParse(a.semestre) ?? 99;
      final semestreB = int.tryParse(b.semestre) ?? 99;
      final cmpSemestre = semestreA.compareTo(semestreB);
      if (cmpSemestre != 0) return cmpSemestre;

      final cmpPlan = a.plan.compareTo(b.plan);
      if (cmpPlan != 0) return cmpPlan;

      return a.nombre.compareTo(b.nombre);
    });

    await LocalStorage.reemplazarCatalogoMaterias(materias);
    await LocalStorage.guardarVersionCatalogoMaterias(versionJson);
  }
}