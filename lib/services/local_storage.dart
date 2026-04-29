import 'package:sqflite/sqflite.dart';

import '../models/parcial_config.dart';
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
    await db.delete('parciales');

    await db.delete(
      'app_state',
      where: 'key IN (?, ?)',
      whereArgs: ['current_session_id', 'ultimo_codigo'],
    );
  }

  static Future<bool> parcialesConfigurados() async {
    final db = await DatabaseService.database;

    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM parciales');

    final total = (result.first['total'] as int?) ?? 0;
    return total > 0;
  }

  static Future<List<ParcialConfig>> obtenerParciales() async {
    final db = await DatabaseService.database;

    final rows = await db.query('parciales', orderBy: 'numero ASC');

    return rows.map(ParcialConfig.fromMap).toList();
  }

  static Future<void> guardarParciales(List<ParcialConfig> parciales) async {
    final db = await DatabaseService.database;

    await db.transaction((txn) async {
      await txn.delete('parciales');

      for (final parcial in parciales) {
        await txn.insert(
          'parciales',
          parcial.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  static Future<int?> obtenerParcialPorFecha(String fechaClase) async {
    final db = await DatabaseService.database;

    final rows = await db.query(
      'parciales',
      where: '? BETWEEN fecha_inicio AND fecha_fin',
      whereArgs: [fechaClase],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return rows.first['numero'] is int
        ? rows.first['numero'] as int
        : int.tryParse(rows.first['numero'].toString());
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
        COUNT(DISTINCT curp) AS total_alumnos
      FROM alumnos
      GROUP BY plantel, semestre, grupo, turno, modalidad
      ORDER BY plantel ASC, semestre ASC, grupo ASC, turno ASC, modalidad ASC
    ''');
  }

  static Future<List<Map<String, dynamic>>> obtenerAlumnosPorGrupo({
    required String plantel,
    required String semestre,
    required String grupo,
    required String turno,
    required String modalidad,
  }) async {
    final db = await DatabaseService.database;

    return db.query(
      'alumnos',
      where:
          'plantel = ? AND semestre = ? AND grupo = ? AND turno = ? AND modalidad = ?',
      whereArgs: [plantel, semestre, grupo, turno, modalidad],
      orderBy: 'nombre ASC',
    );
  }

  static Future<int> contarSesionesPorGrupoYParcial({
    required String plantel,
    required String semestre,
    required String grupo,
    required String turno,
    required String modalidad,
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
        AND parcial = ?
      ''',
      [plantel, semestre, grupo, turno, modalidad, parcial],
    );

    return (result.first['total'] as int?) ?? 0;
  }

  static Future<Map<String, Map<String, dynamic>>> obtenerConteoPorAlumno({
    required String plantel,
    required String semestre,
    required String grupo,
    required String turno,
    required String modalidad,
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
        AND parcial = ?
      GROUP BY curp
      ''',
      [plantel, semestre, grupo, turno, modalidad, parcial],
    );

    final Map<String, Map<String, dynamic>> resultado = {};

    for (final row in rows) {
      final curp = (row['curp'] ?? '').toString();
      resultado[curp] = row;
    }

    return resultado;
  }
}
