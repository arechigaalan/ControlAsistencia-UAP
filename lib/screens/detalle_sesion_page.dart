import 'package:flutter/material.dart';

import '../models/registro_asistencia.dart';
import '../services/local_storage.dart';
import '../widgets/lista_registros_sesion.dart';

class DetalleSesionPage extends StatefulWidget {
  final String sessionId;
  final String fechaClase;
  final String tituloSesion;
  final int parcial;

  const DetalleSesionPage({
    super.key,
    required this.sessionId,
    required this.fechaClase,
    required this.tituloSesion,
    required this.parcial,
  });

  @override
  State<DetalleSesionPage> createState() => _DetalleSesionPageState();
}

class _DetalleSesionPageState extends State<DetalleSesionPage> {
  List<RegistroAsistencia> registros = [];
  List<RegistroAsistencia> asistencias = [];
  List<RegistroAsistencia> justificadas = [];
  List<RegistroAsistencia> faltas = [];

  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarRegistros();
  }

  Future<void> cargarRegistros() async {
    final lista = await LocalStorage.obtenerRegistrosPorSesion(
      widget.sessionId,
    );

    lista.sort((a, b) => b.fechaHoraEscaneo.compareTo(a.fechaHoraEscaneo));

    final asistenciasTemp = lista.where((r) {
      return r.tipoRegistro.toLowerCase() == 'asistencia';
    }).toList();

    final justificadasTemp = lista.where((r) {
      return r.tipoRegistro.toLowerCase() == 'justificada';
    }).toList();

    final registradosCurp = lista.map((r) => r.curp).toSet();

    final faltasTemp = <RegistroAsistencia>[];

    if (lista.isNotEmpty) {
      final referencia = lista.first;

      final alumnosGrupo = await LocalStorage.obtenerAlumnosBasePorGrupo(
        plantel: referencia.plantel,
        semestre: referencia.semestre,
        grupo: referencia.grupo,
        turno: referencia.turno,
        modalidad: referencia.modalidad,
      );

      for (final alumno in alumnosGrupo) {
        final curp = (alumno['curp'] ?? '').toString();

        if (curp.isEmpty) continue;

        if (!registradosCurp.contains(curp)) {
          faltasTemp.add(
            RegistroAsistencia(
              idRegistro: 'falta_${widget.sessionId}_$curp',
              sessionId: widget.sessionId,
              plantel: (alumno['plantel'] ?? '').toString(),
              nombre: (alumno['nombre'] ?? '').toString(),
              matricula: (alumno['matricula'] ?? '').toString(),
              semestre: (alumno['semestre'] ?? '').toString(),
              grupo: (alumno['grupo'] ?? '').toString(),
              turno: (alumno['turno'] ?? '').toString(),
              modalidad: (alumno['modalidad'] ?? '').toString(),
              curp: curp,
              materiaClave: referencia.materiaClave,
              materiaNombre: referencia.materiaNombre,
              tipoRegistro: 'falta',
              fechaClase: widget.fechaClase,
              fechaHoraEscaneo: '',
              codigo: 'FALTA_CALCULADA',
              parcial: widget.parcial,
            ),
          );
        }
      }
    }

    final registrosTemp = [
      ...asistenciasTemp,
      ...justificadasTemp,
      ...faltasTemp,
    ];

    registrosTemp.sort((a, b) => a.nombre.compareTo(b.nombre));

    if (!mounted) return;

    setState(() {
      asistencias = asistenciasTemp;
      justificadas = justificadasTemp;
      faltas = faltasTemp;
      registros = registrosTemp;
      cargando = false;
    });
  }

  Widget _contadorCard({
    required String titulo,
    required int cantidad,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          children: [
            Text(
              '$cantidad',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              titulo,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de sesión'),
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
                    'Sesión seleccionada',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.tituloSesion,
                    style: const TextStyle(
                      color: Color(0xFFE3C076),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _contadorCard(
                        titulo: 'Asistencias',
                        cantidad: asistencias.length,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 10),
                      _contadorCard(
                        titulo: 'Justificadas',
                        cantidad: justificadas.length,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      _contadorCard(
                        titulo: 'Faltas',
                        cantidad: faltas.length,
                        color: Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                  registrosSesion: registros,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}