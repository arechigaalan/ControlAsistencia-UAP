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

    if (!mounted) return;

    setState(() {
      registros = lista;
      cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de sesión')),
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
                    style: TextStyle(color: Colors.white70, fontSize: 13),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Parcial ${widget.parcial}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Alumnos: ${registros.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
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
                child: ListaRegistrosSesion(registrosSesion: registros),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
