import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/registro_asistencia.dart';
import '../services/local_storage.dart';
class DetalleAlumnoEstadisticaPage extends StatefulWidget {
  final String curp;
  final String nombre;
  final String matricula;
  final String plantel;
  final String semestre;
  final String grupo;
  final String turno;
  final String modalidad;
  final int parcial;
  const DetalleAlumnoEstadisticaPage({
    super.key,
    required this.curp,
    required this.nombre,
    required this.matricula,
    required this.plantel,
    required this.semestre,
    required this.grupo,
    required this.turno,
    required this.modalidad,
    required this.parcial,
  });
  @override
  State<DetalleAlumnoEstadisticaPage> createState() =>
      _DetalleAlumnoEstadisticaPageState();
}
class _DetalleAlumnoEstadisticaPageState
    extends State<DetalleAlumnoEstadisticaPage> {
  bool cargando = true;
  List<_DetalleDia> detalles = [];
  int totalSesiones = 0;
  int totalAsistencias = 0;
  int totalJustificadas = 0;
  int totalFaltas = 0;
  double porcentajeAsistencia = 0;
  @override
  void initState() {
    super.initState();
    cargar();
  }
  bool _mismoGrupo(RegistroAsistencia r) {
    return r.plantel == widget.plantel &&
        r.semestre == widget.semestre &&
        r.grupo == widget.grupo &&
        r.turno == widget.turno &&
        r.modalidad == widget.modalidad &&
        r.parcial == widget.parcial;
  }
  Future<void> cargar() async {
    final registros = await LocalStorage.obtenerTodosLosRegistros();
    final registrosGrupo = registros.where(_mismoGrupo).toList();
    final Map<String, List<RegistroAsistencia>> sesiones = {};
    for (final r in registrosGrupo) {
      sesiones.putIfAbsent(r.sessionId, () => []).add(r);
    }
    final lista = <_DetalleDia>[];
    for (final entry in sesiones.entries) {
      final registrosSesion = entry.value;
      registrosSesion.sort(
        (a, b) => a.fechaHoraEscaneo.compareTo(b.fechaHoraEscaneo),
      );
      final referencia = registrosSesion.first;
      RegistroAsistencia? registroAlumno;
      for (final r in registrosSesion) {
        if (r.curp == widget.curp) {
          registroAlumno = r;
          break;
        }
      }
      final estado = registroAlumno == null
          ? 'Falta'
          : registroAlumno.tipoRegistro.toLowerCase() == 'justificada'
              ? 'Justificada'
              : 'Asistencia';
      lista.add(
        _DetalleDia(
          fechaClase: referencia.fechaClase,
          horaSesion: _hora(referencia.fechaHoraEscaneo),
          estado: estado,
        ),
      );
    }
    lista.sort((a, b) => b.fechaClase.compareTo(a.fechaClase));
    final asistencias = lista.where((d) => d.estado == 'Asistencia').length;
    final justificadas = lista.where((d) => d.estado == 'Justificada').length;
    final faltas = lista.where((d) => d.estado == 'Falta').length;
    final total = lista.length;
    final porcentaje =
        total == 0 ? 0.0 : ((asistencias + justificadas) / total) * 100;
    if (!mounted) return;
    setState(() {
      detalles = lista;
      totalSesiones = total;
      totalAsistencias = asistencias;
      totalJustificadas = justificadas;
      totalFaltas = faltas;
      porcentajeAsistencia = porcentaje;
      cargando = false;
    });
  }
  String _fechaVisible(String fecha) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(fecha));
    } catch (_) {
      return fecha;
    }
  }
  String _hora(String fechaHora) {
    if (fechaHora.length >= 16) return fechaHora.substring(11, 16);
    return '—';
  }
  Color _colorEstado(String estado) {
    if (estado == 'Asistencia') return const Color(0xFF1E8E3E);
    if (estado == 'Justificada') return const Color(0xFFA6894B);
    return const Color(0xFFD93025);
  }
  IconData _iconoEstado(String estado) {
    if (estado == 'Falta') return Icons.close;
    return Icons.check;
  }
  Widget _resumenAlumno(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFE3C076),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
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
        title: const Text('Detalle del alumno'),
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
                  colors: [
                    Color(0xFF01152E),
                    Color(0xFF17325C),
                  ],
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
                  Text(
                    widget.nombre,
                    style: const TextStyle(
                      color: Color(0xFFE3C076),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Matrícula/Aspirante: ${widget.matricula}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.semestre}° ${widget.grupo} | Parcial ${widget.parcial}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _resumenAlumno('Sesiones', '$totalSesiones'),
                      const SizedBox(width: 8),
                      _resumenAlumno(
                        'Asis',
                        '${totalAsistencias + totalJustificadas}',
                      ),
                      const SizedBox(width: 8),
                      _resumenAlumno('Falt', '$totalFaltas'),
                      const SizedBox(width: 8),
                      _resumenAlumno(
                        '%',
                        '${porcentajeAsistencia.toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: detalles.isEmpty
                ? const Center(
                    child: Text('No hay sesiones para este parcial'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: detalles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final d = detalles[index];
                      final color = _colorEstado(d.estado);
                      return Container(
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
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _iconoEstado(d.estado),
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _fechaVisible(d.fechaClase),
                                    style: const TextStyle(
                                      color: Color(0xFF01152E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Hora de sesión: ${d.horaSesion}',
                                    style: const TextStyle(
                                      color: Color(0xFF5B6573),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                d.estado,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
class _DetalleDia {
  final String fechaClase;
  final String horaSesion;
  final String estado;
  _DetalleDia({
    required this.fechaClase,
    required this.horaSesion,
    required this.estado,
  });
}