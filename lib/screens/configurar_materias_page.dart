import 'package:flutter/material.dart';

import '../models/materia.dart';
import '../services/local_storage.dart';
import '../services/materias_service.dart';

class ConfigurarMateriasPage extends StatefulWidget {
  final bool obligatorio;

  const ConfigurarMateriasPage({super.key, this.obligatorio = false});

  @override
  State<ConfigurarMateriasPage> createState() => _ConfigurarMateriasPageState();
}

class _ConfigurarMateriasPageState extends State<ConfigurarMateriasPage> {
  List<Materia> catalogo = [];
  Set<String> clavesSeleccionadas = {};
  String busqueda = '';
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final materias = await MateriasService.obtenerCatalogo();
    final seleccionadas = await LocalStorage.obtenerMateriasDocente();

    if (!mounted) return;

    setState(() {
      catalogo = materias;
      clavesSeleccionadas = seleccionadas.map((m) => m.clave).toSet();
      cargando = false;
    });
  }

  List<Materia> get materiasFiltradas {
    final q = busqueda.trim().toUpperCase();
    if (q.isEmpty) return catalogo;

    return catalogo.where((m) {
      return m.nombre.toUpperCase().contains(q) ||
          m.semestre.toUpperCase().contains(q) ||
          m.plan.toUpperCase().contains(q);
    }).toList();
  }

  Future<void> guardar() async {
    if (clavesSeleccionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una materia')),
      );
      return;
    }

    final seleccionadas = catalogo
        .where((m) => clavesSeleccionadas.contains(m.clave))
        .toList();

    await LocalStorage.guardarMateriasDocente(seleccionadas);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Materias guardadas correctamente')),
    );

    Navigator.of(context).pop(true);
  }

  Future<bool> confirmarSalida() async {
    if (!widget.obligatorio || clavesSeleccionadas.isNotEmpty) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debes seleccionar tus materias para usar la app'),
      ),
    );

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filtradas = materiasFiltradas;

    return PopScope(
      canPop: !widget.obligatorio,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final salir = await confirmarSalida();
        if (!mounted) return;
        if (salir && context.mounted) {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.obligatorio,
          title: const Text('Mis materias'),
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
                      'Selecciona las materias que impartes',
                      style: TextStyle(
                        color: Color(0xFFE3C076),
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Después, al iniciar una sesión de escaneo, sólo aparecerán estas materias.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${clavesSeleccionadas.length} seleccionadas',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                onChanged: (value) => setState(() => busqueda = value),
                decoration: InputDecoration(
                  hintText: 'Buscar materia, semestre o plan',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                itemCount: filtradas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final materia = filtradas[index];
                  final seleccionada = clavesSeleccionadas.contains(materia.clave);

                  return Card(
                    child: CheckboxListTile(
                      value: seleccionada,
                      activeColor: const Color(0xFFE3C076),
                      checkColor: const Color(0xFF01152E),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            clavesSeleccionadas.add(materia.clave);
                          } else {
                            clavesSeleccionadas.remove(materia.clave);
                          }
                        });
                      },
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
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              onPressed: guardar,
              icon: const Icon(Icons.save),
              label: const Text('Guardar materias'),
            ),
          ),
        ),
      ),
    );
  }
}
