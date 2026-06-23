import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/materia.dart';
import '../models/registro_asistencia.dart';
import '../models/session_data.dart';
import 'database_service.dart';


class LocalStorage {
  static Future<void> guardarSesion(SessionData sesion) async {
    final db = await DatabaseService.database;

    await db.insert(
      'sesiones',
      sesion.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.insert('app_state', {
      'key': 'current_session_id',
      'value': sesion.sessionId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<SessionData?> obtenerSesion() async {
    final db = await DatabaseService.database;

    final state = await db.query(
      'app_state',
      where: 'key = ?',
      whereArgs: ['current_session_id'],
      limit: 1,
    );

    if (state.isEmpty) return null;

    final sessionId = (state.first['value'] ?? '').toString();
    if (sessionId.isEmpty) return null;

    final rows = await db.query(
      'sesiones',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return SessionData.fromMap(rows.first);
  }


  static Future<void> guardarMateriasDocente(List<Materia> materias) async {
    final db = await DatabaseService.database;

    final value = json.encode(materias.map((m) => m.toMap()).toList());

    await db.insert('app_state', {
      'key': 'materias_docente',
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Materia>> obtenerMateriasDocente() async {
    final db = await DatabaseService.database;

    final rows = await db.query(
      'app_state',
      where: 'key = ?',
      whereArgs: ['materias_docente'],
      limit: 1,
    );

    if (rows.isEmpty) return [];

    final value = (rows.first['value'] ?? '').toString();
    if (value.isEmpty) return [];

    try {
      final data = json.decode(value) as List<dynamic>;
      return data
          .map((item) => Materia.fromMap(Map<String, dynamic>.from(item as Map)))
          .where((m) => m.clave.isNotEmpty && m.nombre.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> materiasDocenteConfiguradas() async {
    final materias = await obtenerMateriasDocente();
    return materias.isNotEmpty;
  }

  static Future<SessionData?> obtenerSesionPorId(String sessionId) async {
    final db = await DatabaseService.database;

    final rows = await db.query(
      'sesiones',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return SessionData.fromMap(rows.first);
  }

  static Future<void> quitarJustificacionManual({
    required String sessionId,
    required String curp,
  }) async {
    final db = await DatabaseService.database;

    await db.delete(
      'registros',
      where: '''
        session_id = ?
        AND curp = ?
        AND tipo_registro = ?
        AND codigo = ?
      ''',
      whereArgs: [
        sessionId,
        curp,
        'justificada',
        'JUSTIFICACION_MANUAL',
      ],
    );
  }

  static Future<void> guardarUltimoCodigo(String codigo) async {
    final db = await DatabaseService.database;

    await db.insert('app_state', {
      'key': 'ultimo_codigo',
      'value': codigo,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String> obtenerUltimoCodigo() async {
    final db = await DatabaseService.database;

    final rows = await db.query(
      'app_state',
      where: 'key = ?',
      whereArgs: ['ultimo_codigo'],
      limit: 1,
    );

    if (rows.isEmpty) return '';
    return (rows.first['value'] ?? '').toString();
  }

  static Future<void> guardarRegistro(RegistroAsistencia registro) async {
    final db = await DatabaseService.database;

    await db.insert(
      'registros',
      registro.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.insert('alumnos', {
      'curp': registro.curp,
      'nombre': registro.nombre,
      'matricula': registro.matricula,
      'plantel': registro.plantel,
      'semestre': registro.semestre,
      'grupo': registro.grupo,
      'turno': registro.turno,
      'modalidad': registro.modalidad,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<RegistroAsistencia>> obtenerTodosLosRegistros() async {
    final db = await DatabaseService.database;

    final rows = await db.query('registros', orderBy: 'fecha_hora_escaneo ASC');

    return rows.map(RegistroAsistencia.fromMap).toList();
  }

  static Future<List<RegistroAsistencia>> obtenerRegistrosPorSesion(
    String sessionId,
  ) async {
    final db = await DatabaseService.database;

    final rows = await db.query(
      'registros',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'fecha_hora_escaneo ASC',
    );

    return rows.map(RegistroAsistencia.fromMap).toList();
  }

  static Future<void> eliminarRegistroPorId(String idRegistro) async {
    final db = await DatabaseService.database;

    await db.delete(
      'registros',
      where: 'id_registro = ?',
      whereArgs: [idRegistro],
    );
  }

  static Future<int> contarRegistros() async {
    final db = await DatabaseService.database;

    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM registros');

    return (result.first['total'] as int?) ?? 0;
  }

  static Future<int> contarSesiones() async {
    final db = await DatabaseService.database;

    final result = await db.rawQuery(
      'SELECT COUNT(DISTINCT session_id) AS total FROM registros',
    );

    return (result.first['total'] as int?) ?? 0;
  }

  static Future<void> borrarTodosLosRegistros() async {
  final db = await DatabaseService.database;

  await db.delete('registros');
  await db.delete('sesiones');
  await db.delete('alumnos');
  await db.delete('materias');

  await db.delete(
    'app_state',
    where: 'key IN (?, ?, ?, ?)',
    whereArgs: [
      'current_session_id',
      'ultimo_codigo',
      'materias_docente',
      'materias_catalogo_version',
    ],
  );
}

  static Future<void> guardarCatalogoMaterias(List<Materia> materias) async {
  final db = await DatabaseService.database;
  final batch = db.batch();

  for (final materia in materias) {
    batch.insert(
      'materias',
      materia.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  await batch.commit(noResult: true);
}

static Future<List<Materia>> obtenerCatalogoMaterias() async {
  final db = await DatabaseService.database;

  final rows = await db.query(
    'materias',
    orderBy: 'CAST(semestre AS INTEGER) ASC, plan ASC, nombre ASC',
  );

  return rows.map(Materia.fromMap).toList();
}

static Future<bool> catalogoMateriasExiste() async {
  final db = await DatabaseService.database;

  final result = await db.rawQuery(
    'SELECT COUNT(*) AS total FROM materias',
  );

  final total = (result.first['total'] as int?) ?? 0;
  return total > 0;
}

static Future<void> reemplazarCatalogoMaterias(List<Materia> materias) async {
  final db = await DatabaseService.database;
  final batch = db.batch();

  batch.delete('materias');

  for (final materia in materias) {
    batch.insert(
      'materias',
      materia.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  await batch.commit(noResult: true);
}

static Future<void> guardarModoHorizontalExperimental(bool activo) async {
  final db = await DatabaseService.database;

  await db.insert(
    'app_state',
    {
      'key': 'modo_horizontal_experimental',
      'value': activo ? '1' : '0',
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

static Future<bool> obtenerModoHorizontalExperimental() async {
  final db = await DatabaseService.database;

  final rows = await db.query(
    'app_state',
    where: 'key = ?',
    whereArgs: ['modo_horizontal_experimental'],
    limit: 1,
  );

  if (rows.isEmpty) return false;

  return (rows.first['value'] ?? '0').toString() == '1';
}

static Future<void> eliminarSesionPorId(String sessionId) async {
  final db = await DatabaseService.database;

  await db.delete(
    'sesiones',
    where: 'session_id = ?',
    whereArgs: [sessionId],
  );

  await db.delete(
    'app_state',
    where: 'key = ? AND value = ?',
    whereArgs: ['current_session_id', sessionId],
  );
}

static Future<int> obtenerVersionCatalogoMaterias() async {
  final db = await DatabaseService.database;

  final rows = await db.query(
    'app_state',
    where: 'key = ?',
    whereArgs: ['materias_catalogo_version'],
    limit: 1,
  );

  if (rows.isEmpty) return 0;

  return int.tryParse((rows.first['value'] ?? '0').toString()) ?? 0;
}

static Future<void> actualizarMateriaSesionYRegistros({
  required String sessionId,
  required String materiaClave,
  required String materiaNombre,
}) async {
  final db = await DatabaseService.database;

  await db.transaction((txn) async {
    await txn.update(
      'sesiones',
      {
        'materia_clave': materiaClave,
        'materia_nombre': materiaNombre,
      },
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );

    await txn.update(
      'registros',
      {
        'materia_clave': materiaClave,
        'materia_nombre': materiaNombre,
      },
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  });
}

static Future<void> actualizarParcialSesionYRegistros({
  required String sessionId,
  required int parcial,
}) async {
  final db = await DatabaseService.database;

  await db.transaction((txn) async {
    await txn.update(
      'sesiones',
      {'parcial': parcial},
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );

    await txn.update(
      'registros',
      {'parcial': parcial},
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  });
}

static Future<void> eliminarAsistenciaManual({
  required String sessionId,
  required String curp,
}) async {
  final db = await DatabaseService.database;

  await db.delete(
    'registros',
    where: '''
      session_id = ?
      AND curp = ?
      AND tipo_registro = ?
    ''',
    whereArgs: [
      sessionId,
      curp,
      'asistencia',
    ],
  );
}

static Future<void> eliminarGrupoMateria({
  required String plantel,
  required String semestre,
  required String grupo,
  required String turno,
  required String modalidad,
  required String materiaClave,
}) async {
  final db = await DatabaseService.database;

  await db.transaction((txn) async {
    await txn.delete(
      'registros',
      where: '''
        plantel = ?
        AND semestre = ?
        AND grupo = ?
        AND turno = ?
        AND modalidad = ?
        AND materia_clave = ?
      ''',
      whereArgs: [
        plantel,
        semestre,
        grupo,
        turno,
        modalidad,
        materiaClave,
      ],
    );

    await txn.delete(
      'alumnos',
      where: '''
        plantel = ?
        AND semestre = ?
        AND grupo = ?
        AND turno = ?
        AND modalidad = ?
      ''',
      whereArgs: [
        plantel,
        semestre,
        grupo,
        turno,
        modalidad,
      ],
    );

    await txn.delete(
      'sesiones',
      where: '''
        session_id NOT IN (
          SELECT DISTINCT session_id FROM registros
        )
      ''',
    );
  });
}

static Future<void> actualizarFechaSesionYRegistros({
  required String sessionId,
  required String fechaClase,
}) async {
  final db = await DatabaseService.database;

  await db.transaction((txn) async {
    await txn.update(
      'sesiones',
      {'fecha_clase': fechaClase},
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );

    final registros = await txn.query(
      'registros',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );

    for (final r in registros) {
      final fechaHoraActual = (r['fecha_hora_escaneo'] ?? '').toString();

      String nuevaFechaHora = fechaClase;

      if (fechaHoraActual.length >= 16) {
        nuevaFechaHora = '$fechaClase ${fechaHoraActual.substring(11)}';
      }

      await txn.update(
        'registros',
        {
          'fecha_clase': fechaClase,
          'fecha_hora_escaneo': nuevaFechaHora,
        },
        where: 'id_registro = ?',
        whereArgs: [r['id_registro']],
      );
    }
  });
}

static Future<void> guardarVersionCatalogoMaterias(int version) async {
  final db = await DatabaseService.database;

  await db.insert(
    'app_state',
    {
      'key': 'materias_catalogo_version',
      'value': version.toString(),
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

static Future<List<Map<String, dynamic>>> obtenerAlumnosBasePorGrupo({
  required String plantel,
  required String semestre,
  required String grupo,
  required String turno,
  required String modalidad,
}) async {
  final db = await DatabaseService.database;

  return db.query(
    'alumnos',
    where: '''
      plantel = ?
      AND semestre = ?
      AND grupo = ?
      AND turno = ?
      AND modalidad = ?
    ''',
    whereArgs: [
      plantel,
      semestre,
      grupo,
      turno,
      modalidad,
    ],
    orderBy: 'nombre ASC',
  );
}

  // =========================
  // ESTADÍSTICAS
  // =========================

  static Future<List<Map<String, dynamic>>> obtenerGruposDetectados() async {
    final db = await DatabaseService.database;

    return db.rawQuery('''
      SELECT
        plantel,
        semestre,
        grupo,
        turno,
        modalidad,
        materia_clave,
        materia_nombre,
        COUNT(DISTINCT curp) AS total_alumnos
      FROM registros
      GROUP BY plantel, semestre, grupo, turno, modalidad, materia_clave, materia_nombre
      ORDER BY plantel ASC, semestre ASC, grupo ASC, turno ASC, modalidad ASC, materia_nombre ASC
    ''');
  }

  static Future<List<Map<String, dynamic>>> obtenerAlumnosPorGrupo({
    required String plantel,
    required String semestre,
    required String grupo,
    required String turno,
    required String modalidad,
    required String materiaClave,
  }) async {
    final db = await DatabaseService.database;

    return db.rawQuery(
      '''
      SELECT DISTINCT
        curp,
        nombre,
        matricula,
        plantel,
        semestre,
        grupo,
        turno,
        modalidad
      FROM registros
      WHERE plantel = ?
        AND semestre = ?
        AND grupo = ?
        AND turno = ?
        AND modalidad = ?
        AND materia_clave = ?
      ORDER BY nombre ASC
      ''',
      [plantel, semestre, grupo, turno, modalidad, materiaClave],
    );
  }

static Future<void> eliminarSesionYRegistros(String sessionId) async {
  final db = await DatabaseService.database;

  await db.transaction((txn) async {
    await txn.delete(
      'registros',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );

    await txn.delete(
      'sesiones',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );

    await txn.delete(
      'app_state',
      where: 'key = ? AND value = ?',
      whereArgs: ['current_session_id', sessionId],
    );
  });
}


  static Future<List<Map<String, dynamic>>> obtenerGruposConocidos() async {
    final db = await DatabaseService.database;

    return db.rawQuery('''
      SELECT DISTINCT
        plantel,
        semestre,
        grupo,
        turno,
        modalidad
      FROM alumnos
      WHERE plantel != ''
        AND semestre != ''
        AND grupo != ''
        AND turno != ''
        AND modalidad != ''
      ORDER BY plantel ASC, semestre ASC, grupo ASC, turno ASC, modalidad ASC
    ''');
    }

  static Future<List<int>> obtenerParcialesPorGrupoMateria({
    required String plantel,
    required String semestre,
    required String grupo,
    required String turno,
    required String modalidad,
    required String materiaClave,
  }) async {
    final db = await DatabaseService.database;

    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT parcial
      FROM registros
      WHERE plantel = ?
        AND semestre = ?
        AND grupo = ?
        AND turno = ?
        AND modalidad = ?
        AND materia_clave = ?
      ORDER BY parcial ASC
      ''',
      [plantel, semestre, grupo, turno, modalidad, materiaClave],
    );

    return rows
        .map((row) => row['parcial'] is int
            ? row['parcial'] as int
            : int.tryParse((row['parcial'] ?? '').toString()) ?? 0)
        .where((p) => p >= 1 && p <= 5)
        .toList();
  }

  static Future<int> contarSesionesPorGrupoYParcial({
    required String plantel,
    required String semestre,
    required String grupo,
    required String turno,
    required String modalidad,
    required String materiaClave,
    required int parcial,
  }) async {
    final db = await DatabaseService.database;

    final result = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT session_id) AS total
      FROM registros
      WHERE plantel = ?
        AND semestre = ?
        AND grupo = ?
        AND turno = ?
        AND modalidad = ?
        AND materia_clave = ?
        AND parcial = ?
      ''',
      [plantel, semestre, grupo, turno, modalidad, materiaClave, parcial],
    );

    return (result.first['total'] as int?) ?? 0;
  }

  static Future<Map<String, Map<String, dynamic>>> obtenerConteoPorAlumno({
    required String plantel,
    required String semestre,
    required String grupo,
    required String turno,
    required String modalidad,
    required String materiaClave,
    required int parcial,
  }) async {
    final db = await DatabaseService.database;

    final rows = await db.rawQuery(
      '''
      SELECT
        curp,
        SUM(CASE WHEN tipo_registro = 'asistencia' THEN 1 ELSE 0 END) AS asistencias,
        SUM(CASE WHEN tipo_registro = 'justificada' THEN 1 ELSE 0 END) AS justificadas,
        COUNT(*) AS total_validas
      FROM registros
      WHERE plantel = ?
        AND semestre = ?
        AND grupo = ?
        AND turno = ?
        AND modalidad = ?
        AND materia_clave = ?
        AND parcial = ?
      GROUP BY curp
      ''',
      [plantel, semestre, grupo, turno, modalidad, materiaClave, parcial],
    );

    final Map<String, Map<String, dynamic>> resultado = {};

    for (final row in rows) {
      final curp = (row['curp'] ?? '').toString();
      resultado[curp] = row;
    }

    return resultado;
  }

  static Future<List<RegistroAsistencia>>
    obtenerRegistrosPendientesSincronizar() async {
  final db = await DatabaseService.database;

  final rows = await db.query(
    'registros',
    where: 'sincronizado = ?',
    whereArgs: [0],
    orderBy: 'fecha_hora_escaneo ASC',
  );

  return rows.map(RegistroAsistencia.fromMap).toList();
}

static Future<int> contarRegistrosPendientesSincronizar() async {
  final db = await DatabaseService.database;

  final result = await db.rawQuery('''
    SELECT COUNT(*) AS total
    FROM registros
    WHERE sincronizado = 0
  ''');

  return (result.first['total'] as int?) ?? 0;
}

static Future<void> marcarRegistrosComoSincronizados({
  required List<String> idsRegistros,
}) async {
  if (idsRegistros.isEmpty) return;

  final db = await DatabaseService.database;
  final fecha = DateTime.now().toIso8601String();

  final batch = db.batch();

  for (final id in idsRegistros) {
    batch.update(
      'registros',
      {
        'sincronizado': 1,
        'fecha_sincronizacion': fecha,
      },
      where: 'id_registro = ?',
      whereArgs: [id],
    );
  }

  await batch.commit(noResult: true);
}

static Future<int> contarRegistrosSincronizados() async {
  final db = await DatabaseService.database;

  final result = await db.rawQuery('''
    SELECT COUNT(*) AS total
    FROM registros
    WHERE sincronizado = 1
  ''');

  return (result.first['total'] as int?) ?? 0;
}
}
