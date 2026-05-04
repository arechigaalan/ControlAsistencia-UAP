import 'package:flutter/material.dart';

import 'detalle_alumno_estadistica_page.dart';
import '../services/local_storage.dart';
import '../services/turno_helper.dart';

class DetalleEstadisticasGrupoPage extends StatefulWidget {
  final String plantel;
  final String semestre;
  final String grupo;
  final String turno;
  final String modalidad;
  final String materiaClave;
  final String materiaNombre;

  const DetalleEstadisticasGrupoPage({
    super.key,
    required this.plantel,
    required this.semestre,
    required this.grupo,
    required this.turno,
    required this.modalidad,
    required this.materiaClave,
    required this.materiaNombre,
  });

  @override
  State<DetalleEstadisticasGrupoPage> createState() =>
      _DetalleEstadisticasGrupoPageState();
}

class _DetalleEstadisticasGrupoPageState
    extends State<DetalleEstadisticasGrupoPage> {
  bool cargando = true;
  int parcialSeleccionado = 1;

  List<int> parcialesDisponibles = [];
  List<_AlumnoEstadistica> alumnos = [];

  int totalSesiones = 0;
  int totalAlumnos = 0;
  int totalAsistenciasValidas = 0;
  int totalFaltas = 0;
  double promedioAsistencia = 0;

  @override
  void initState() {
    super.initState();
    cargarParciales();
  }

  Future<void> cargarParciales() async {
    final parciales = await LocalStorage.obtenerParciales();

    final disponibles = parciales.map((p) => p.numero).toList()..sort();

    if (disponibles.isEmpty) {
      disponibles.add(1);
    }

    parcialSeleccionado = disponibles.first;
    parcialesDisponibles = disponibles;

    await cargarEstadisticas();
  }

  Future<void> cargarEstadisticas() async {
    setState(() {
      cargando = true;
    });

    final alumnosRaw = await LocalStorage.obtenerAlumnosPorGrupo(
      plantel: widget.plantel,
      semestre: widget.semestre,
      grupo: widget.grupo,
      turno: widget.turno,
      modalidad: widget.modalidad,
      materiaClave: widget.materiaClave,
    );

    final sesiones = await LocalStorage.contarSesionesPorGrupoYParcial(
      plantel: widget.plantel,
      semestre: widget.semestre,
      grupo: widget.grupo,
      turno: widget.turno,
      modalidad: widget.modalidad,
      materiaClave: widget.materiaClave,
      parcial: parcialSeleccionado,
    );

    final conteo = await LocalStorage.obtenerConteoPorAlumno(
      plantel: widget.plantel,
      semestre: widget.semestre,
      grupo: widget.grupo,
      turno: widget.turno,
      modalidad: widget.modalidad,
      materiaClave: widget.materiaClave,
      parcial: parcialSeleccionado,
    );

    final lista = alumnosRaw.map((a) {
      final curp = (a['curp'] ?? '').toString();
      final datos = conteo[curp];

      final asistencias = _toInt(datos?['asistencias']);
      final justificadas = _toInt(datos?['justificadas']);
      final validas = asistencias + justificadas;

      final faltas = sesiones - validas;
      final porcentaje = sesiones == 0 ? 0.0 : (validas / sesiones) * 100;

      return _AlumnoEstadistica(
        curp: a['curp'].toString(),
        nombre: (a['nombre'] ?? '').toString(),
        matricula: (a['matricula'] ?? '').toString(),
        asistencias: asistencias,
        justificadas: justificadas,
        faltas: faltas < 0 ? 0 : faltas,
        porcentaje: porcentaje,
      );
    }).toList();

    lista.sort((a, b) => a.nombre.compareTo(b.nombre));

    final validasTotal = lista.fold<int>(
      0,
      (total, a) => total + a.asistencias + a.justificadas,
    );

    final faltasTotal = lista.fold<int>(0, (total, a) => total + a.faltas);

    final maxAsistencias = sesiones * lista.length;
    final promedio = maxAsistencias == 0
        ? 0.0
        : (validasTotal / maxAsistencias) * 100;

    if (!mounted) return;

    setState(() {
      alumnos = lista;
      totalSesiones = sesiones;
      totalAlumnos = lista.length;
      totalAsistenciasValidas = validasTotal;
      totalFaltas = faltasTotal;
      promedioAsistencia = promedio;
      cargando = false;
    });
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  Color _colorPorcentaje(double porcentaje) {
    if (porcentaje >= 80) return const Color(0xFF1E8E3E);
    if (porcentaje >= 60) return const Color(0xFFB26A00);
    return const Color(0xFFD93025);
  }

  @override
  Widget build(BuildContext context) {
    final tituloGrupo =
        '${widget.plantel} | ${widget.semestre}° ${widget.grupo} | '
        '${TurnoHelper.nombreTurno(widget.turno)} | '
        '${TurnoHelper.nombreModalidad(widget.modalidad)} | ${widget.materiaNombre}';

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
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
                  Text(
                    tituloGrupo,
                    style: const TextStyle(
                      color: Color(0xFFE3C076),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: parcialSeleccionado,
                        dropdownColor: const Color(0xFF01152E),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        items: parcialesDisponibles
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text('Parcial $p'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          if (value == null) return;

                          setState(() {
                            parcialSeleccionado = value;
                          });

                          await cargarEstadisticas();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (totalSesiones > 0)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _resumenChip('Ses', '$totalSesiones'),
                        _resumenChip('Alumnos', '$totalAlumnos'),
                        _resumenChip(
                          'Prom',
                          '${promedioAsistencia.toStringAsFixed(0)}%',
                        ),
                      ],
                    )
                  else
                    const Text(
                      'No hay datos para este parcial',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (cargando)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: totalSesiones == 0
                  ? const Center(child: Text('No hay datos para este parcial'))
                  : alumnos.isEmpty
                  ? const Center(
                      child: Text('No hay alumnos detectados en este grupo'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: alumnos.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final a = alumnos[index];
                        final color = _colorPorcentaje(a.porcentaje);

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetalleAlumnoEstadisticaPage(
                                  curp: a.curp,
                                  nombre: a.nombre,
                                  matricula: a.matricula,
                                  plantel: widget.plantel,
                                  semestre: widget.semestre,
                                  grupo: widget.grupo,
                                  turno: widget.turno,
                                  modalidad: widget.modalidad,
                                  materiaClave: widget.materiaClave,
                                  materiaNombre: widget.materiaNombre,
                                  parcial: parcialSeleccionado,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.nombre,
                                        style: const TextStyle(
                                          color: Color(0xFF01152E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Matrícula: ${a.matricula}',
                                        style: const TextStyle(
                                          color: Color(0xFF5B6573),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          _chip(
                                            'Asist: ${a.asistencias}',
                                            const Color(0xFFEAF7EE),
                                            const Color(0xFF1E8E3E),
                                          ),
                                          _chip(
                                            'Just: ${a.justificadas}',
                                            const Color(0xFFFFF8E8),
                                            const Color(0xFF8A6B20),
                                          ),
                                          _chip(
                                            'Falt: ${a.faltas}',
                                            const Color(0xFFFFF1F0),
                                            const Color(0xFFD93025),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${a.porcentaje.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _resumenChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

class _AlumnoEstadistica {
  final String curp;
  final String nombre;
  final String matricula;
  final int asistencias;
  final int justificadas;
  final int faltas;
  final double porcentaje;

  _AlumnoEstadistica({
    required this.curp,
    required this.nombre,
    required this.matricula,
    required this.asistencias,
    required this.justificadas,
    required this.faltas,
    required this.porcentaje,
  });
}
