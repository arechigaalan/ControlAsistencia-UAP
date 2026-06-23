import '../models/registro_asistencia.dart';
import 'auth_service.dart';
import 'local_storage.dart';

class SyncService {
  static Future<SyncResumen> obtenerResumen() async {
    final pendientes =
        await LocalStorage.contarRegistrosPendientesSincronizar();

    return SyncResumen(
      pendientes: pendientes,
    );
  }

  static Future<SyncResult> sincronizarPruebaLocal() async {
    var docenteId = await AuthService.obtenerDocenteIdInt();

    if (docenteId <= 0) {
      // Temporal mientras estamos en pruebas locales.
      docenteId = 1;
    }

    final pendientes =
        await LocalStorage.obtenerRegistrosPendientesSincronizar();

    if (pendientes.isEmpty) {
      return SyncResult.ok(
        enviados: 0,
        mensaje: 'No hay registros pendientes por sincronizar.',
      );
    }

    final ids = pendientes.map((r) => r.idRegistro).toList();

    await LocalStorage.marcarRegistrosComoSincronizados(
      idsRegistros: ids,
    );

    return SyncResult.ok(
      enviados: pendientes.length,
      mensaje: 'Sincronización local simulada correctamente.',
    );
  }

  static List<Map<String, dynamic>> construirPayload(
    List<RegistroAsistencia> registros,
  ) {
    return registros.map((r) {
      return {
        'id_registro': r.idRegistro,
        'session_id': r.sessionId,
        'docente_id': r.docenteId,
        'plantel': r.plantel,
        'matricula': r.matricula,
        'curp': r.curp,
        'materia_clave': r.materiaClave,
        'materia_nombre': r.materiaNombre,
        'tipo_registro': r.tipoRegistro,
        'fecha_clase': r.fechaClase,
        'fecha_hora_escaneo': r.fechaHoraEscaneo,
        'parcial': r.parcial,
      };
    }).toList();
  }
}

class SyncResumen {
  final int pendientes;

  const SyncResumen({
    required this.pendientes,
  });
}

class SyncResult {
  final bool success;
  final int enviados;
  final String mensaje;

  const SyncResult._({
    required this.success,
    required this.enviados,
    required this.mensaje,
  });

  factory SyncResult.ok({
    required int enviados,
    required String mensaje,
  }) {
    return SyncResult._(
      success: true,
      enviados: enviados,
      mensaje: mensaje,
    );
  }

  factory SyncResult.error(String mensaje) {
    return SyncResult._(
      success: false,
      enviados: 0,
      mensaje: mensaje,
    );
  }
}