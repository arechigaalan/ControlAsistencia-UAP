import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database_service.dart';

class ExportadorCsv {
  static Future<String?> exportarYCompartir() async {
    final db = await DatabaseService.database;

    final rows = await db.rawQuery('''
      SELECT
        id_registro,
        session_id,
        plantel,
        nombre,
        curp,
        matricula,
        semestre,
        grupo,
        turno,
        modalidad,
        tipo_registro,
        parcial,
        fecha_clase,
        fecha_hora_escaneo
      FROM registros
      ORDER BY fecha_hora_escaneo ASC
    ''');

    if (rows.isEmpty) {
      return null;
    }

    final csvRows = <List<dynamic>>[
      [
        'id_registro',
        'session_id',
        'plantel',
        'nombre',
        'curp',
        'matricula',
        'semestre',
        'grupo',
        'turno',
        'modalidad',
        'tipo_registro',
        'parcial',
        'fecha_clase',
        'fecha_hora_escaneo',
      ],
    ];

    for (final row in rows) {
      csvRows.add([
        row['id_registro'] ?? '',
        row['session_id'] ?? '',
        row['plantel'] ?? '',
        row['nombre'] ?? '',
        row['curp'] ?? '',
        row['matricula'] ?? '',
        row['semestre'] ?? '',
        row['grupo'] ?? '',
        row['turno'] ?? '',
        row['modalidad'] ?? '',
        row['tipo_registro'] ?? '',
        row['parcial'] ?? '',
        row['fecha_clase'] ?? '',
        row['fecha_hora_escaneo'] ?? '',
      ]);
    }

    final csvContent = csv.encode(csvRows);
    final bytes = utf8.encode('\uFEFF$csvContent');

    final dir = await getApplicationDocumentsDirectory();
    final nombreArchivo =
        'asistencias_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${dir.path}/$nombreArchivo');

    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Registros de asistencia',
      ),
    );

    return file.path;
  }
}