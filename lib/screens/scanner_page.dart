import 'dart:async';

import 'package:flutter/material.dart';
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
import 'configurar_parciales_page.dart';

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
  Color bordeFeedbackColor = Colors.transparent;

  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

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

  @override
  void initState() {
    super.initState();
    initSesion();
  }

  @override
  void dispose() {
    overlayTimer?.cancel();
    cooldown?.cancel();
    scannerController.dispose();
    super.dispose();
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: materias.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final materia = materias[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFFF8E8),
                            child: Icon(Icons.menu_book, color: Color(0xFF01152E)),
                          ),
                          title: Text(
                            materia.nombre,
                            style: const TextStyle(
                              color: Color(0xFF01152E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Clave: ${materia.clave} · Semestre: ${materia.semestre}',
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
        );
      },
    );
  }

  Future<void> initSesion() async {
    try {
      final fechaActual = UtilsFechas.fechaClase(widget.fechaClase);
      final parcialCalculado = await LocalStorage.obtenerParcialPorFecha(
        fechaActual,
      );

      if (parcialCalculado == null) {
        if (!mounted) return;

        final irConfig = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'Parcial no configurado',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF01152E),
              ),
            ),
            content: const Text(
              textAlign: TextAlign.justify,
              'La fecha actual no pertenece a ningún parcial. Debe configurar o modificar las fechas de los parciales para continuar.',
              style: TextStyle(color: Color(0xFF5B6573), fontSize: 15),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: _secondaryDialogButtonStyle(),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: _primaryDialogButtonStyle(),
                        child: const Text(
                          'Configurar',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (irConfig == true) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConfigurarParcialesPage()),
          );

          if (!mounted) return;
          final nuevoParcial = await LocalStorage.obtenerParcialPorFecha(
            fechaActual,
          );

          if (nuevoParcial == null) {
            if (!mounted) return;
            Navigator.of(context).pop();
            return;
          }

          parcial = nuevoParcial;
        } else {
          Navigator.of(context).pop();
          return;
        }
      } else {
        parcial = parcialCalculado;
      }

      final materia = await seleccionarMateriaSesion();
      if (materia == null) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }
      materiaSeleccionada = materia;
      materiaSesion = materia.nombre;

      final sesionGuardada = await LocalStorage.obtenerSesion();

      if (sesionGuardada == null) {
        await _crearNuevaSesion();
        return;
      }

      final mismaSesion =
          sesionGuardada.tipoRegistro == widget.tipoRegistro &&
          sesionGuardada.fechaClase == fechaActual &&
          sesionGuardada.parcial == parcial &&
          sesionGuardada.materiaClave == materiaSeleccionada!.clave;

      if (!mismaSesion) {
        await _crearNuevaSesion();
        return;
      }

      final lista = await LocalStorage.obtenerRegistrosPorSesion(
        sesionGuardada.sessionId,
      );

      final ultimo = await LocalStorage.obtenerUltimoCodigo();

      if (lista.isNotEmpty) {
        final primero = lista.first;

        grupoSesion = TurnoHelper.grupoCompleto(
          semestre: primero.semestre,
          grupo: primero.grupo,
        );

        turnoSesion = TurnoHelper.nombreTurno(primero.turno);
      }

      if (!mounted) return;

      final decision = await dialogoSesion(
        lista.length,
        sesionGuardada.materiaNombre,
      );

      if (!mounted) return;

      if (decision == 'continuar') {
        final listaInvertida = lista.reversed.toList();
        final primero = lista.isNotEmpty ? lista.first : null;

        setState(() {
          sesion = sesionGuardada;
          ultimoCodigo = ultimo;
          capturados = lista.length;
          registrosSesion = listaInvertida;

          grupoSesion = primero == null
              ? ''
              : TurnoHelper.grupoCompleto(
                  semestre: primero.semestre,
                  grupo: primero.grupo,
                );

          turnoSesion = primero == null
              ? ''
              : TurnoHelper.nombreTurno(primero.turno);

          modalidadSesion = primero == null
              ? ''
              : TurnoHelper.nombreModalidad(primero.modalidad);

          plantelSesion = primero == null ? '' : primero.plantel;
          horaSesion = _obtenerHoraSesion(sesionGuardada.fechaCreacion);
          materiaSesion = sesionGuardada.materiaNombre;
          cargando = false;
        });
      } else {
        await _crearNuevaSesion();
      }
    } catch (_) {
      if (materiaSeleccionada == null) {
        final materia = await seleccionarMateriaSesion();
        if (materia == null) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        materiaSeleccionada = materia;
        materiaSesion = materia.nombre;
      }
      await _crearNuevaSesion();
    }
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

  Future<String?> dialogoSesion(int count, String materiaNombre) {
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
                    'Materia: $materiaNombre\n\n'
                    'Alumnos registrados: $count\n\n'
                    '¿Deseas continuar o crear una nueva?'
              : 'Existe una sesión activa.\n'
                    'Alumnos registrados: $count\n'
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

    cooldown = Timer(const Duration(milliseconds: 800), () {
      puedeEscanear = true;
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

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
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
                            _headerChip('Parcial ${parcial ?? '-'}'),
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
                        Text(
                          materiaSesion.isEmpty ? 'Materia: —' : 'Materia: $materiaSesion',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE3C076),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
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
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
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
                              controller: scannerController,
                              onDetect: (capture) async {
                                if (!puedeEscanear) return;
                                if (capture.barcodes.isEmpty) return;

                                final code = capture.barcodes.first.rawValue
                                    ?.trim();

                                if (code != null && code.isNotEmpty) {
                                  await procesar(code);
                                }
                              },
                            ),
                            OverlayEstado(
                              estado: estado,
                              mensaje: mensaje,
                              detalle: detalleOverlay,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                  ),
                ),
              ],
            ),
            if (mostrandoGuardado)
              Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
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
              ),
          ],
        ),
      ),
    );
  }
}
