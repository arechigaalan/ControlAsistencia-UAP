import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/materia.dart';
import '../models/registro_asistencia.dart';
import '../models/session_data.dart';
import '../services/local_storage.dart';
import '../services/sonido_service.dart';
import '../services/turno_helper.dart';
import '../services/utils_fechas.dart';
import '../widgets/lista_registros_sesion.dart';
import '../widgets/overlay_estado.dart';

class ScannerPage extends StatefulWidget {
  final String tipoRegistro;
  final DateTime fechaClase;

  const ScannerPage({
    super.key,
    required this.tipoRegistro,
    required this.fechaClase,
  });

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  SessionData? sesion;
  bool cargando = true;
  bool mostrandoGuardado = false;
  bool modoHorizontalExperimental = false;

  int? parcial;
  Materia? materiaSeleccionada;

  int capturados = 0;
  String ultimoCodigo = '';
  List<RegistroAsistencia> registrosSesion = [];

  String grupoSesion = '';
  String turnoSesion = '';
  String modalidadSesion = '';
  String plantelSesion = '';
  String horaSesion = '';
  String materiaSesion = '';

  EstadoEscaneo estado = EstadoEscaneo.ninguno;
  String mensaje = '';
  String detalleOverlay = '';

  Timer? overlayTimer;
  Timer? cooldown;
  bool puedeEscanear = true;
  bool esperandoSiguienteEscaneo = false;

  static const Duration tiempoCooldownEscaneo = Duration(milliseconds: 2500);

  Color bordeFeedbackColor = Colors.transparent;

  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  @override
  void initState() {
    super.initState();
    _configurarOrientacion();
    initSesion();
  }

  Future<void> _configurarOrientacion() async {
    final experimental = await LocalStorage.obtenerModoHorizontalExperimental();

    if (experimental) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }

    if (!mounted) return;

    setState(() {
      modoHorizontalExperimental = experimental;
    });
  }

  Future<void> marcarAsistenciaATodos() async {
  if (sesion == null || parcial == null) return;

  if (plantelSesion.isEmpty ||
      grupoSesion.isEmpty ||
      registrosSesion.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Primero escanea al menos un alumno para identificar el grupo.',
        ),
      ),
    );
    return;
  }

  final referencia = registrosSesion.first;

  final alumnos = await LocalStorage.obtenerAlumnosBasePorGrupo(
    plantel: referencia.plantel,
    semestre: referencia.semestre,
    grupo: referencia.grupo,
    turno: referencia.turno,
    modalidad: referencia.modalidad,
  );

  if (!mounted) return;

  if (alumnos.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No hay alumnos conocidos para este grupo.'),
      ),
    );
    return;
  }

  final registrados = registrosSesion.map((r) => r.curp).toSet();

  final pendientes = alumnos.where((a) {
    final curp = (a['curp'] ?? '').toString();
    return curp.isNotEmpty && !registrados.contains(curp);
  }).toList();

  if (pendientes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todos los alumnos conocidos ya están registrados.'),
      ),
    );
    return;
  }

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      title: const Text(
        'Marcar asistencia a todos',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF01152E),
        ),
      ),
      content: Text(
        'Se registrará asistencia para ${pendientes.length} alumnos '
        'que aún no están en esta sesión.\n\n'
        '¿Deseas continuar?',
        style: const TextStyle(
          color: Color(0xFF5B6573),
          fontSize: 15,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: _secondaryDialogButtonStyle(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: _primaryDialogButtonStyle(),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );

  if (confirmar != true) return;

  final ahora = DateTime.now();
  final nuevos = <RegistroAsistencia>[];

  for (final alumno in pendientes) {
    final registro = RegistroAsistencia(
      idRegistro:
          '${DateTime.now().microsecondsSinceEpoch}_${alumno['curp']}',
      sessionId: sesion!.sessionId,
      plantel: (alumno['plantel'] ?? '').toString(),
      nombre: (alumno['nombre'] ?? '').toString(),
      matricula: (alumno['matricula'] ?? '').toString(),
      semestre: (alumno['semestre'] ?? '').toString(),
      grupo: (alumno['grupo'] ?? '').toString(),
      turno: (alumno['turno'] ?? '').toString(),
      modalidad: (alumno['modalidad'] ?? '').toString(),
      curp: (alumno['curp'] ?? '').toString(),
      materiaClave: sesion!.materiaClave,
      materiaNombre: sesion!.materiaNombre,
      tipoRegistro: 'asistencia',
      fechaClase: UtilsFechas.fechaClase(widget.fechaClase),
      fechaHoraEscaneo: UtilsFechas.fechaHora(ahora),
      codigo: 'ASISTENCIA_MANUAL_TODOS',
      parcial: parcial!,
    );

    await LocalStorage.guardarRegistro(registro);
    nuevos.add(registro);
  }

  final actualizados = await LocalStorage.obtenerRegistrosPorSesion(
    sesion!.sessionId,
  );

  if (!mounted) return;

  setState(() {
    registrosSesion = actualizados.reversed.toList();
    capturados = registrosSesion.length;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Se registraron ${nuevos.length} asistencias.',
      ),
    ),
  );
}

  Future<void> _alternarModoHorizontalExperimental() async {
    final nuevoValor = !modoHorizontalExperimental;

    await LocalStorage.guardarModoHorizontalExperimental(nuevoValor);

    if (nuevoValor) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }

    if (!mounted) return;

    setState(() {
      modoHorizontalExperimental = nuevoValor;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nuevoValor
              ? 'Vista horizontal experimental activada'
              : 'Vista horizontal desactivada',
        ),
      ),
    );
  }

  @override
  void dispose() {
    overlayTimer?.cancel();
    cooldown?.cancel();
    scannerController.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  Widget _headerChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE3C076),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF01152E),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  ButtonStyle _secondaryDialogButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: const Color(0xFF01152E),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      minimumSize: const Size(110, 48),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    );
  }

  ButtonStyle _primaryDialogButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: const Color(0xFFE3C076),
      foregroundColor: const Color(0xFF01152E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      minimumSize: const Size(110, 48),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    );
  }

  Future<Materia?> _materiaDesdeSesion(SessionData sesionActual) async {
    final materias = await LocalStorage.obtenerMateriasDocente();

    for (final materia in materias) {
      if (materia.clave == sesionActual.materiaClave) {
        return materia;
      }
    }

    return Materia(
      clave: sesionActual.materiaClave,
      nombre: sesionActual.materiaNombre,
      semestre: '',
      plan: '',
    );
  }

  Future<Materia?> seleccionarMateriaSesion() async {
    final materias = await LocalStorage.obtenerMateriasDocente();

    if (!mounted) return null;

    if (materias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero configura las materias que impartes'),
        ),
      );
      Navigator.of(context).pop();
      return null;
    }

    return showModalBottomSheet<Materia>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '¿A qué materia pertenece esta sesión?',
                    style: TextStyle(
                      color: Color(0xFF01152E),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Selecciona una de tus materias configuradas.',
                    style: TextStyle(color: Color(0xFF5B6573), fontSize: 14),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      itemCount: materias.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final materia = materias[index];

                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFFFF8E8),
                              child: Icon(
                                Icons.menu_book,
                                color: Color(0xFF01152E),
                              ),
                            ),
                            title: Text(
                              materia.nombre,
                              style: const TextStyle(
                                color: Color(0xFF01152E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${materia.semestre}° semestre · Plan ${materia.plan}',
                              style: const TextStyle(color: Color(0xFF5B6573)),
                            ),
                            onTap: () => Navigator.of(sheetContext).pop(materia),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<int?> seleccionarParcialSesion() async {
    if (!mounted) return null;

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '¿A qué parcial pertenece esta sesión?',
                    style: TextStyle(
                      color: Color(0xFF01152E),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Selecciona el parcial que corresponde a esta clase.',
                    style: TextStyle(color: Color(0xFF5B6573), fontSize: 14),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      itemCount: 5,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final numero = index + 1;

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFFFF8E8),
                              child: Text(
                                '$numero',
                                style: const TextStyle(
                                  color: Color(0xFF01152E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              'Parcial $numero',
                              style: const TextStyle(
                                color: Color(0xFF01152E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: parcial == numero
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFFE3C076),
                                  )
                                : null,
                            onTap: () => Navigator.of(sheetContext).pop(numero),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

Future<void> _crearNuevaSesion() async {
  final nueva = crearSesion(
    tipoRegistro: widget.tipoRegistro,
    fechaClase: widget.fechaClase,
    parcial: parcial ?? 1,
    materia: materiaSeleccionada!,
  );

  await LocalStorage.guardarSesion(nueva);
  await LocalStorage.guardarUltimoCodigo('');

  if (!mounted) return;

  setState(() {
    sesion = nueva;
    ultimoCodigo = '';
    capturados = 0;
    registrosSesion = [];
    grupoSesion = '';
    turnoSesion = '';
    modalidadSesion = '';
    plantelSesion = '';
    horaSesion = _obtenerHoraSesion(nueva.fechaCreacion);
    materiaSesion = nueva.materiaNombre;
    cargando = false;
  });
}

Future<void> initSesion() async {
  try {
    final sesionGuardada = await LocalStorage.obtenerSesion();

    if (sesionGuardada != null) {
      final lista = await LocalStorage.obtenerRegistrosPorSesion(
        sesionGuardada.sessionId,
      );

      // Si la sesión existe pero no tiene registros, se elimina y no se pregunta.
      if (lista.isEmpty) {
        await LocalStorage.eliminarSesionPorId(sesionGuardada.sessionId);
        await LocalStorage.guardarUltimoCodigo('');
      } else {
        final ultimo = await LocalStorage.obtenerUltimoCodigo();
        final primero = lista.first;

        grupoSesion = TurnoHelper.grupoCompleto(
          semestre: primero.semestre,
          grupo: primero.grupo,
        );

        turnoSesion = TurnoHelper.nombreTurno(primero.turno);
        modalidadSesion = TurnoHelper.nombreModalidad(primero.modalidad);
        plantelSesion = primero.plantel;

        if (!mounted) return;

        final decision = await dialogoSesion(
          lista.length,
          sesionGuardada.materiaNombre,
          sesionGuardada.parcial,
        );

        if (!mounted) return;

        if (decision == 'continuar') {
          final listaInvertida = lista.reversed.toList();
          final materia = await _materiaDesdeSesion(sesionGuardada);

          if (!mounted) return;

          setState(() {
            sesion = sesionGuardada;
            parcial = sesionGuardada.parcial;
            materiaSeleccionada = materia;
            ultimoCodigo = ultimo;
            capturados = lista.length;
            registrosSesion = listaInvertida;

            grupoSesion = TurnoHelper.grupoCompleto(
              semestre: primero.semestre,
              grupo: primero.grupo,
            );

            turnoSesion = TurnoHelper.nombreTurno(primero.turno);
            modalidadSesion = TurnoHelper.nombreModalidad(primero.modalidad);
            plantelSesion = primero.plantel;
            horaSesion = _obtenerHoraSesion(sesionGuardada.fechaCreacion);
            materiaSesion = sesionGuardada.materiaNombre;
            cargando = false;
          });

          return;
        }
      }
    }

    final materiasDocente = await LocalStorage.obtenerMateriasDocente();

    if (materiasDocente.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero configura las materias que impartes'),
        ),
      );

      Navigator.of(context).pop();
      return;
    }

    if (materiasDocente.length == 1) {
      final materia = materiasDocente.first;

      materiaSeleccionada = materia;
      materiaSesion = materia.nombre;
    } else {
      final materia = await seleccionarMateriaSesion();

      if (materia == null) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      materiaSeleccionada = materia;
      materiaSesion = materia.nombre;
    }

    final parcialElegido = await seleccionarParcialSesion();

    if (parcialElegido == null) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    parcial = parcialElegido;

    await _crearNuevaSesion();
  } catch (_) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No fue posible iniciar la sesión')),
    );

    Navigator.of(context).pop();
  }
}

Future<void> cambiarMateriaSesion() async {
  if (sesion == null) return;

  final nuevaMateria = await seleccionarMateriaSesion();

  if (nuevaMateria == null) return;

  if (nuevaMateria.clave == sesion!.materiaClave) return;

  if (!mounted) return;

  if (registrosSesion.isNotEmpty) {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text(
          'Cambiar materia',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF01152E),
          ),
        ),
        content: const Text(
          'Esta sesión ya tiene registros. Si cambias la materia, todos los '
          'registros de esta sesión se actualizarán a la nueva materia.',
          style: TextStyle(color: Color(0xFF5B6573), fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: _secondaryDialogButtonStyle(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: _primaryDialogButtonStyle(),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
  }

  final sesionActual = sesion!;

  final sesionActualizada = SessionData(
    sessionId: sesionActual.sessionId,
    fechaCreacion: sesionActual.fechaCreacion,
    activa: sesionActual.activa,
    tipoRegistro: sesionActual.tipoRegistro,
    fechaClase: sesionActual.fechaClase,
    parcial: sesionActual.parcial,
    materiaClave: nuevaMateria.clave,
    materiaNombre: nuevaMateria.nombre,
  );

  await LocalStorage.actualizarMateriaSesionYRegistros(
    sessionId: sesionActual.sessionId,
    materiaClave: nuevaMateria.clave,
    materiaNombre: nuevaMateria.nombre,
  );

  final registrosActualizados = await LocalStorage.obtenerRegistrosPorSesion(
    sesionActual.sessionId,
  );

  if (!mounted) return;

  setState(() {
    sesion = sesionActualizada;
    materiaSeleccionada = nuevaMateria;
    materiaSesion = nuevaMateria.nombre;
    registrosSesion = registrosActualizados.reversed.toList();
    capturados = registrosSesion.length;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Materia cambiada a ${nuevaMateria.nombre}')),
  );
}

  Future<void> cambiarParcialSesion() async {
    if (sesion == null) return;

    materiaSeleccionada ??= await _materiaDesdeSesion(sesion!);

    if (!mounted) return;

    if (registrosSesion.isNotEmpty) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Cambiar parcial',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF01152E),
            ),
          ),
          content: const Text(
            'Esta sesión ya tiene registros. Si cambias el parcial, todos los '
            'registros de esta sesión se actualizarán al nuevo parcial.',
            style: TextStyle(color: Color(0xFF5B6573), fontSize: 15),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: _secondaryDialogButtonStyle(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: _primaryDialogButtonStyle(),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;
    }

    final nuevoParcial = await seleccionarParcialSesion();

    if (nuevoParcial == null || nuevoParcial == parcial) return;

    final sesionActual = sesion!;

    final sesionActualizada = SessionData(
      sessionId: sesionActual.sessionId,
      fechaCreacion: sesionActual.fechaCreacion,
      activa: sesionActual.activa,
      tipoRegistro: sesionActual.tipoRegistro,
      fechaClase: sesionActual.fechaClase,
      parcial: nuevoParcial,
      materiaClave: sesionActual.materiaClave,
      materiaNombre: sesionActual.materiaNombre,
    );

    await LocalStorage.actualizarParcialSesionYRegistros(
      sessionId: sesionActual.sessionId,
      parcial: nuevoParcial,
    );

    final registrosActualizados = await LocalStorage.obtenerRegistrosPorSesion(
      sesionActual.sessionId,
    );

    if (!mounted) return;

    setState(() {
      parcial = nuevoParcial;
      sesion = sesionActualizada;
      registrosSesion = registrosActualizados.reversed.toList();
      capturados = registrosSesion.length;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Parcial cambiado a $nuevoParcial')),
    );
  }

  Future<String?> dialogoSesion(
    int count,
    String materiaNombre,
    int parcialSesion,
  ) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Sesión anterior',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF01152E),
          ),
        ),
        content: Text(
          grupoSesion.isNotEmpty
              ? 'Existe una sesión activa de:\n'
                    '$grupoSesion | $turnoSesion\n'
                    'Materia: $materiaNombre\n'
                    'Parcial: $parcialSesion\n\n'
                    'Alumnos registrados: $count\n\n'
                    '¿Deseas continuar o crear una nueva?'
              : 'Existe una sesión activa.\n'
                    'Materia: $materiaNombre\n'
                    'Parcial: $parcialSesion\n'
                    'Alumnos registrados: $count\n\n'
                    '¿Deseas continuar o crear una nueva?',
          style: const TextStyle(color: Color(0xFF5B6573), fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('continuar'),
            style: _secondaryDialogButtonStyle(),
            child: const Text('Continuar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('nueva'),
            style: _primaryDialogButtonStyle(),
            child: const Text('Nueva'),
          ),
        ],
      ),
    );
  }

  Future<bool> confirmarSalida() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Guardar sesión',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF01152E),
          ),
        ),
        content: const Text(
          '¿Desea guardar y finalizar la sesión? Los registros no se perderán.',
          style: TextStyle(color: Color(0xFF5B6573), fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: _secondaryDialogButtonStyle(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: _primaryDialogButtonStyle(),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    return salir ?? false;
  }

  Future<void> intentarSalir() async {
  // Si no hay registros, salir directamente sin preguntar.
  if (registrosSesion.isEmpty) {
    if (sesion != null) {
      await LocalStorage.eliminarSesionPorId(sesion!.sessionId);
      await LocalStorage.guardarUltimoCodigo('');
    }

    if (!mounted) return;

    Navigator.of(context).pop();
    return;
  }

  final salir = await confirmarSalida();

  if (!mounted) return;

  if (salir) {
    setState(() {
      mostrandoGuardado = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    Navigator.of(context).pop();
  }
}

  SessionData crearSesion({
    required String tipoRegistro,
    required DateTime fechaClase,
    required int parcial,
    required Materia materia,
  }) {
    final now = DateTime.now();

    return SessionData(
      sessionId:
          '${tipoRegistro}_p${parcial}_${materia.clave}_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(now)}',
      fechaCreacion: UtilsFechas.fechaHora(now),
      activa: true,
      tipoRegistro: tipoRegistro,
      fechaClase: UtilsFechas.fechaClase(fechaClase),
      parcial: parcial,
      materiaClave: materia.clave,
      materiaNombre: materia.nombre,
    );
  }

  String generarIdRegistro() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  String _obtenerHoraSesion(String fechaCreacion) {
    try {
      final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(fechaCreacion);
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      if (fechaCreacion.length >= 16) {
        return fechaCreacion.substring(11, 16);
      }
      return '';
    }
  }

  void mostrarOverlay(
    EstadoEscaneo nuevoEstado,
    String nuevoMensaje, {
    String detalle = '',
  }) {
    overlayTimer?.cancel();

    if (!mounted) return;

    setState(() {
      estado = nuevoEstado;
      mensaje = nuevoMensaje;
      detalleOverlay = detalle;
    });

    overlayTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      setState(() {
        estado = EstadoEscaneo.ninguno;
        mensaje = '';
        detalleOverlay = '';
      });
    });
  }

  void activarBordeFeedback(Color color) {
    if (!mounted) return;

    setState(() {
      bordeFeedbackColor = color;
    });

    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;

      setState(() {
        bordeFeedbackColor = Colors.transparent;
      });
    });
  }

  Future<void> eliminarRegistroSesion(RegistroAsistencia registro) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Eliminar registro',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF01152E),
          ),
        ),
        content: Text(
          '¿Deseas eliminar el registro de: ${registro.nombre}?',
          style: const TextStyle(color: Color(0xFF5B6573), fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: _secondaryDialogButtonStyle(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: _primaryDialogButtonStyle(),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmacion != true) return;

    await LocalStorage.eliminarRegistroPorId(registro.idRegistro);

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      setState(() {
        registrosSesion.removeWhere((r) => r.idRegistro == registro.idRegistro);
        capturados = registrosSesion.length;
        ultimoCodigo = registrosSesion.isNotEmpty
            ? registrosSesion.first.codigo
            : '';

        if (registrosSesion.isNotEmpty) {
          final ref = registrosSesion.first;
          grupoSesion = TurnoHelper.grupoCompleto(
            semestre: ref.semestre,
            grupo: ref.grupo,
          );
          turnoSesion = TurnoHelper.nombreTurno(ref.turno);
          modalidadSesion = TurnoHelper.nombreModalidad(ref.modalidad);
          plantelSesion = ref.plantel;
        } else {
          grupoSesion = '';
          turnoSesion = '';
          modalidadSesion = '';
          plantelSesion = '';
        }
      });

      await LocalStorage.guardarUltimoCodigo(ultimoCodigo);

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Registro eliminado')),
      );
    });
  }

  Future<void> procesar(String codigo) async {
    if (!puedeEscanear || sesion == null || parcial == null) return;

    puedeEscanear = false;
    cooldown?.cancel();

    if (mounted) {
      setState(() {
        esperandoSiguienteEscaneo = true;
      });
    }

    cooldown = Timer(tiempoCooldownEscaneo, () {
      if (!mounted) return;

      setState(() {
        puedeEscanear = true;
        esperandoSiguienteEscaneo = false;
      });
    });

    if (codigo == ultimoCodigo) {
      activarBordeFeedback(Colors.orange);
      mostrarOverlay(EstadoEscaneo.duplicado, 'Ya fue escaneado');
      await Future.wait([SonidoService.sonidoError(), SonidoService.vibrar()]);
      return;
    }

    final partes = codigo.split('|').map((e) => e.trim()).toList();

    if (partes.length != 8) {
      activarBordeFeedback(Colors.red);
      mostrarOverlay(EstadoEscaneo.error, 'QR inválido');
      await Future.wait([SonidoService.sonidoError(), SonidoService.vibrar()]);
      return;
    }

    final plantel = partes[0];
    final matricula = partes[1];
    final nombre = partes[2];
    final semestre = partes[3];
    final grupo = partes[4];
    final turno = partes[5];
    final modalidad = partes[6].toUpperCase();
    final curp = partes[7].toUpperCase();

    if (plantel.isEmpty ||
        matricula.isEmpty ||
        nombre.isEmpty ||
        semestre.isEmpty ||
        grupo.isEmpty ||
        turno.isEmpty ||
        modalidad.isEmpty ||
        curp.isEmpty) {
      activarBordeFeedback(Colors.red);
      mostrarOverlay(EstadoEscaneo.error, 'QR inválido');
      await Future.wait([SonidoService.sonidoError(), SonidoService.vibrar()]);
      return;
    }

    if (turno != '1' && turno != '2' && turno != '4') {
      activarBordeFeedback(Colors.red);
      mostrarOverlay(EstadoEscaneo.error, 'Turno inválido');
      await Future.wait([SonidoService.sonidoError(), SonidoService.vibrar()]);
      return;
    }

    if (modalidad != 'E' && modalidad != 'S') {
      activarBordeFeedback(Colors.red);
      mostrarOverlay(EstadoEscaneo.error, 'Modalidad inválida');
      await Future.wait([SonidoService.sonidoError(), SonidoService.vibrar()]);
      return;
    }

    if (registrosSesion.isNotEmpty) {
      final referencia = registrosSesion.first;

      final mismoSemestre = referencia.semestre == semestre;
      final mismoGrupo = referencia.grupo.toUpperCase() == grupo.toUpperCase();

      if (!mismoSemestre || !mismoGrupo) {
        activarBordeFeedback(Colors.red);
        mostrarOverlay(
          EstadoEscaneo.error,
          'Alumno de otro grupo',
          detalle: 'Este QR pertenece a $semestre° $grupo',
        );

        await Future.wait([
          SonidoService.sonidoError(),
          SonidoService.vibrar(),
        ]);

        return;
      }
    }

    final yaExisteEnSesion = registrosSesion.any((r) => r.curp == curp);

    if (yaExisteEnSesion) {
      activarBordeFeedback(Colors.orange);
      mostrarOverlay(EstadoEscaneo.duplicado, 'Alumno ya registrado');
      await Future.wait([SonidoService.sonidoError(), SonidoService.vibrar()]);
      return;
    }

    final ahora = DateTime.now();

    final registro = RegistroAsistencia(
      idRegistro: generarIdRegistro(),
      sessionId: sesion!.sessionId,
      plantel: plantel,
      nombre: nombre,
      matricula: matricula,
      semestre: semestre,
      grupo: grupo,
      turno: turno,
      modalidad: modalidad,
      curp: curp,
      materiaClave: sesion!.materiaClave,
      materiaNombre: sesion!.materiaNombre,
      tipoRegistro: widget.tipoRegistro,
      fechaClase: UtilsFechas.fechaClase(widget.fechaClase),
      fechaHoraEscaneo: UtilsFechas.fechaHora(ahora),
      codigo: codigo,
      parcial: parcial!,
    );

    await LocalStorage.guardarRegistro(registro);
    await LocalStorage.guardarUltimoCodigo(codigo);

    if (!mounted) return;

    setState(() {
      capturados += 1;
      ultimoCodigo = codigo;
      registrosSesion.insert(0, registro);

      grupoSesion = grupoSesion.isEmpty
          ? TurnoHelper.grupoCompleto(semestre: semestre, grupo: grupo)
          : grupoSesion;

      turnoSesion = turnoSesion.isEmpty
          ? TurnoHelper.nombreTurno(turno)
          : turnoSesion;

      modalidadSesion = modalidadSesion.isEmpty
          ? TurnoHelper.nombreModalidad(modalidad)
          : modalidadSesion;

      plantelSesion = plantelSesion.isEmpty ? plantel : plantelSesion;
    });

    activarBordeFeedback(Colors.green);

    mostrarOverlay(EstadoEscaneo.exito, 'Escaneado con éxito', detalle: nombre);

    await Future.wait([SonidoService.sonidoExito(), SonidoService.vibrar()]);
  }

  Widget _bannerSesion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF01152E), Color(0xFF17325C)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    plantelSesion.isEmpty ? '—' : plantelSesion,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE3C076),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: cambiarParcialSesion,
                  child: _headerChip('Parcial ${parcial ?? '-'}'),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '${grupoSesion.isEmpty ? '—' : grupoSesion} | '
              '${turnoSesion.isEmpty ? '—' : turnoSesion} | '
              '${modalidadSesion.isEmpty ? '—' : modalidadSesion}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 7),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final materias = await LocalStorage.obtenerMateriasDocente();

                if (materias.length <= 1) return;

                await cambiarMateriaSesion();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  materiaSesion.isEmpty ? 'Materia: —' : 'Materia: $materiaSesion',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE3C076),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${UtilsFechas.fechaHumana(widget.fechaClase)} - '
                    '${horaSesion.isEmpty ? '—' : horaSesion}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$capturados alumnos',
                  style: const TextStyle(
                    color: Color(0xFFE3C076),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _scannerPanel(String scannerOrientationKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: bordeFeedbackColor, width: 6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                key: ValueKey('scanner_$scannerOrientationKey'),
                controller: scannerController,
                onDetect: (capture) async {
                  if (!puedeEscanear) return;
                  if (capture.barcodes.isEmpty) return;

                  final code = capture.barcodes.first.rawValue?.trim();

                  if (code != null && code.isNotEmpty) {
                    await procesar(code);
                  }
                },
              ),
              Positioned(
                top: 12,
                right: 12,
                child: FloatingActionButton.small(
                  heroTag: 'switchCamera_$scannerOrientationKey',
                  backgroundColor: const Color(0xFF01152E),
                  foregroundColor: const Color(0xFFE3C076),
                  onPressed: () async {
                    await scannerController.switchCamera();
                  },
                  child: const Icon(Icons.cameraswitch),
                ),
              ),
              OverlayEstado(
                estado: estado,
                mensaje: mensaje,
                detalle: detalleOverlay,
              ),
              if (esperandoSiguienteEscaneo)
                Positioned(
                  bottom: 24,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Espere para el siguiente escaneo...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listaPanel({
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 10, 16, 10),
  }) {
    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListaRegistrosSesion(
          registrosSesion: registrosSesion,
          onEliminar: eliminarRegistroSesion,
        ),
      ),
    );
  }

  Widget _contenidoNormal(String scannerOrientationKey) {
    return Column(
      children: [
        _bannerSesion(),
        Expanded(
          flex: 2,
          child: _scannerPanel(scannerOrientationKey),
        ),
        Expanded(
          flex: 3,
          child: _listaPanel(),
        ),
      ],
    );
  }

  Widget _contenidoTabletHorizontal(String scannerOrientationKey) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _bannerSesion(),
              Expanded(
                child: _scannerPanel(scannerOrientationKey),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: _listaPanel(
            padding: const EdgeInsets.fromLTRB(0, 14, 16, 10),
          ),
        ),
      ],
    );
  }

  Widget _overlayGuardado() {
    if (!mostrandoGuardado) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF01152E),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 72,
                color: Color(0xFFE3C076),
              ),
              SizedBox(height: 14),
              Text(
                'Sesión guardada',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final media = MediaQuery.of(context);
    final size = media.size;

    final esTablet = size.shortestSide >= 600;
    final esHorizontal = size.width > size.height;
    final scannerOrientationKey = esHorizontal ? 'landscape' : 'portrait';

    final usarLayoutTabletHorizontal =
        modoHorizontalExperimental && esTablet && esHorizontal;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await intentarSalir();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Registro de asistencia'),
          leadingWidth: 120,
          leading: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: intentarSalir,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: const [
                  Icon(Icons.check, size: 24, color: Color(0xFFE3C076)),
                  SizedBox(width: 6),
                  Text(
                    'Guardar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE3C076),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (registrosSesion.isNotEmpty)
              IconButton(
                tooltip: 'Marcar asistencia a todos',
                icon: const Icon(
                  Icons.group_add,
                  color: Color(0xFFE3C076),
                ),
                onPressed: marcarAsistenciaATodos,
              ),
            IconButton(
              tooltip: modoHorizontalExperimental
                  ? 'Desactivar vista horizontal experimental'
                  : 'Activar vista horizontal experimental',
              icon: Icon(
                modoHorizontalExperimental
                    ? Icons.screen_rotation
                    : Icons.stay_current_portrait,
                color: const Color(0xFFE3C076),
              ),
              onPressed: _alternarModoHorizontalExperimental,
            ),
          ],
        ),
        body: Stack(
          children: [
            usarLayoutTabletHorizontal
                ? _contenidoTabletHorizontal(scannerOrientationKey)
                : _contenidoNormal(scannerOrientationKey),
            _overlayGuardado(),
          ],
        ),
      ),
    );
  }
}
