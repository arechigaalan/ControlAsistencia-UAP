import 'package:flutter/material.dart';

import '../services/local_storage.dart';
import '../services/turno_helper.dart';
import 'detalle_estadisticas_grupo_page.dart';

class EstadisticasGruposPage extends StatefulWidget {
  const EstadisticasGruposPage({super.key});

  @override
  State<EstadisticasGruposPage> createState() =>
      _EstadisticasGruposPageState();
}

class _EstadisticasGruposPageState extends State<EstadisticasGruposPage> {
  bool cargando = true;
  List<_GrupoResumen> grupos = [];

  @override
  void initState() {
    super.initState();
    cargarGrupos();
  }

  Future<void> cargarGrupos() async {
    final rows = await LocalStorage.obtenerGruposDetectados();

    final lista = rows.map((row) {
      return _GrupoResumen(
        plantel: (row['plantel'] ?? '').toString(),
        semestre: (row['semestre'] ?? '').toString(),
        grupo: (row['grupo'] ?? '').toString(),
        turno: (row['turno'] ?? '').toString(),
        modalidad: (row['modalidad'] ?? '').toString(),
        totalAlumnos: row['total_alumnos'] is int
            ? row['total_alumnos'] as int
            : int.tryParse((row['total_alumnos'] ?? '0').toString()) ?? 0,
      );
    }).toList();

    if (!mounted) return;

    setState(() {
      grupos = lista;
      cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (grupos.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No hay grupos detectados'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas por grupo'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: grupos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final g = grupos[index];

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetalleEstadisticasGrupoPage(
                      plantel: g.plantel,
                      semestre: g.semestre,
                      grupo: g.grupo,
                      turno: g.turno,
                      modalidad: g.modalidad,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.groups,
                        color: Color(0xFF01152E),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.plantel,
                            style: const TextStyle(
                              color: Color(0xFF01152E),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${g.semestre}° ${g.grupo} | '
                            '${TurnoHelper.nombreTurno(g.turno)} | '
                            '${TurnoHelper.nombreModalidad(g.modalidad)}',
                            style: const TextStyle(
                              color: Color(0xFF5B6573),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Alumnos detectados: ${g.totalAlumnos}',
                            style: const TextStyle(
                              color: Color(0xFF5B6573),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF01152E),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GrupoResumen {
  final String plantel;
  final String semestre;
  final String grupo;
  final String turno;
  final String modalidad;
  final int totalAlumnos;

  _GrupoResumen({
    required this.plantel,
    required this.semestre,
    required this.grupo,
    required this.turno,
    required this.modalidad,
    required this.totalAlumnos,
  });
}