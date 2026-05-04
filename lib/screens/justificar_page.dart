import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/registro_asistencia.dart';
import '../services/local_storage.dart';
import '../services/sonido_service.dart';
import '../services/utils_fechas.dart';
import '../widgets/overlay_estado.dart';

class JustificarPage extends StatefulWidget {
  final String sessionId;
  final String fechaClase;
  final int parcial;
  final String materiaClave;
  final String materiaNombre;

  const JustificarPage({
    super.key,
    required this.sessionId,
    required this.fechaClase,
    required this.parcial,
    required this.materiaClave,
    required this.materiaNombre,
  });

  @override
  State<JustificarPage> createState() => _JustificarPageState();
}

class _JustificarPageState extends State<JustificarPage> {
  EstadoEscaneo estado = EstadoEscaneo.ninguno;
  String mensaje = '';
  String detalleOverlay = '';

  Timer? overlayTimer;
  bool puedeEscanear = true;
  Color bordeFeedbackColor = Colors.transparent;

  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  @override
  void dispose() {
    overlayTimer?.cancel();
    scannerController.dispose();
    super.dispose();
  }

  String generarIdRegistro() {
    return DateTime.now().millisecondsSinceEpoch.toString();
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

  Future<void> procesarJustificacion(String codigo) async {
    if (!puedeEscanear) return;

    puedeEscanear = false;

    final partes = codigo.split('|').map((e) => e.trim()).toList();

    if (partes.length != 8) {
      activarBordeFeedback(Colors.red);
      mostrarOverlay(EstadoEscaneo.error, 'QR inválido');
      await Future.wait([SonidoService.sonidoError(), SonidoService.vibrar()]);
      puedeEscanear = true;
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
      puedeEscanear = true;
      return;
    }

    if (turno != '1' && turno != '2' && turno != '4') {
      activarBordeFeedback(Colors.red);
      mostrarOverlay(EstadoEscaneo.error, 'Turno inválido');
      await Future.wait([SonidoService.sonidoError(), SonidoService.vibrar()]);
      puedeEscanear = true;
      return;
    }

    if (modalidad != 'E' && modalidad != 'S') {
      activarBordeFeedback(Colors.red);
      mostrarOverlay(EstadoEscaneo.error, 'Modalidad inválida');
      await Future.wait([SonidoService.sonidoError(), SonidoService.vibrar()]);
      puedeEscanear = true;
      return;
    }

    final registrosSesion = await LocalStorage.obtenerRegistrosPorSesion(
      widget.sessionId,
    );

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

    puedeEscanear = true;
    return;
  }
}

    final yaExiste = registrosSesion.any((r) => r.curp == curp);

    if (yaExiste) {
      activarBordeFeedback(Colors.orange);
      mostrarOverlay(EstadoEscaneo.duplicado, 'Alumno ya registrado');
      await Future.wait([SonidoService.sonidoError(), SonidoService.vibrar()]);
      puedeEscanear = true;
      return;
    }

    final ahora = DateTime.now();

    final registro = RegistroAsistencia(
      idRegistro: generarIdRegistro(),
      sessionId: widget.sessionId,
      plantel: plantel,
      nombre: nombre,
      matricula: matricula,
      semestre: semestre,
      grupo: grupo,
      turno: turno,
      modalidad: modalidad,
      curp: curp,
      materiaClave: widget.materiaClave,
      materiaNombre: widget.materiaNombre,
      tipoRegistro: 'justificada',
      fechaClase: widget.fechaClase,
      fechaHoraEscaneo: UtilsFechas.fechaHora(ahora),
      codigo: codigo,
      parcial: widget.parcial,
    );

    await LocalStorage.guardarRegistro(registro);

    activarBordeFeedback(Colors.green);

    mostrarOverlay(
      EstadoEscaneo.exito,
      'Justificación agregada',
      detalle: nombre,
    );

    await Future.wait([SonidoService.sonidoExito(), SonidoService.vibrar()]);
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar justificación'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF01152E), Color(0xFF17325C)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Escanea el QR del alumno',
                    style: TextStyle(
                      color: Color(0xFFE3C076),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Se agregará como justificación en ${widget.materiaNombre}, Parcial ${widget.parcial}. ',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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

                          final code =
                              capture.barcodes.first.rawValue?.trim();

                          if (code != null && code.isNotEmpty) {
                            await procesarJustificacion(code);
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
        ],
      ),
    );
  }
}