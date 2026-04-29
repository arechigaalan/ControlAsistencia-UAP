import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/parcial_config.dart';
import '../services/local_storage.dart';

class ConfigurarParcialesPage extends StatefulWidget {
  final bool obligatorio;

  const ConfigurarParcialesPage({super.key, this.obligatorio = false});

  @override
  State<ConfigurarParcialesPage> createState() =>
      _ConfigurarParcialesPageState();
}

class _ConfigurarParcialesPageState extends State<ConfigurarParcialesPage> {
  bool cargando = true;
  int cantidadParciales = 4;
  List<_ParcialTemp> parciales = [];

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final existentes = await LocalStorage.obtenerParciales();

    if (existentes.isEmpty) {
      parciales = List.generate(
        cantidadParciales,
        (i) => _ParcialTemp(numero: i + 1),
      );
    } else {
      cantidadParciales = existentes.length;
      parciales = existentes
          .map(
            (p) => _ParcialTemp(
              numero: p.numero,
              fechaInicio: p.fechaInicio,
              fechaFin: p.fechaFin,
            ),
          )
          .toList();
    }

    if (!mounted) return;

    setState(() {
      cargando = false;
    });

    if (widget.obligatorio && existentes.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mostrarAvisoInicial();
      });
    }
  }

  Future<void> _mostrarAvisoInicial() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Configuración requerida',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF01152E),
          ),
        ),
        content: const Text(
          textAlign: TextAlign.justify,
          'Se deben configurar las fechas de los parciales antes de usar la aplicación. Esto sólo se realiza una vez y después podrá modificarlo desde la configuración.',
          style: TextStyle(color: Color(0xFF5B6573), fontSize: 15),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void cambiarCantidad(int cantidad) {
    setState(() {
      cantidadParciales = cantidad;

      parciales = List.generate(cantidad, (i) {
        final previo = i < parciales.length ? parciales[i] : null;

        return _ParcialTemp(
          numero: i + 1,
          fechaInicio: previo?.fechaInicio ?? '',
          fechaFin: previo?.fechaFin ?? '',
        );
      });
    });
  }

  Future<void> seleccionarFecha({
    required int index,
    required bool inicio,
  }) async {
    final now = DateTime.now();

    final seleccion = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );

    if (seleccion == null) return;

    final fecha = DateFormat('yyyy-MM-dd').format(seleccion);

    setState(() {
      if (inicio) {
        parciales[index].fechaInicio = fecha;
      } else {
        parciales[index].fechaFin = fecha;
      }
    });
  }

  bool haySolapamiento() {
    final rangos = parciales.map((p) {
      return (
        inicio: DateTime.parse(p.fechaInicio),
        fin: DateTime.parse(p.fechaFin),
        numero: p.numero,
      );
    }).toList();

    for (int i = 0; i < rangos.length; i++) {
      for (int j = i + 1; j < rangos.length; j++) {
        final a = rangos[i];
        final b = rangos[j];

        final seEnciman =
            !a.fin.isBefore(b.inicio) && !b.fin.isBefore(a.inicio);

        if (seEnciman) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'El Parcial ${a.numero} se encima con el Parcial ${b.numero}',
              ),
            ),
          );
          return true;
        }
      }
    }

    return false;
  }

  Future<void> guardar() async {
    for (final p in parciales) {
      if (p.fechaInicio.isEmpty || p.fechaFin.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes llenar todas las fechas')),
        );
        return;
      }

      final inicio = DateTime.parse(p.fechaInicio);
      final fin = DateTime.parse(p.fechaFin);

      if (fin.isBefore(inicio)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('El Parcial ${p.numero} tiene fechas inválidas'),
          ),
        );
        return;
      }
    }

    final ordenados = [...parciales]
      ..sort((a, b) => a.numero.compareTo(b.numero));

    for (int i = 1; i < ordenados.length; i++) {
      final anterior = ordenados[i - 1];
      final actual = ordenados[i];

      final finAnterior = DateTime.parse(anterior.fechaFin);
      final inicioActual = DateTime.parse(actual.fechaInicio);

      if (inicioActual.isBefore(finAnterior) ||
          inicioActual.isAtSameMomentAs(finAnterior)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El Parcial ${actual.numero} debe iniciar después del Parcial ${anterior.numero}',
            ),
          ),
        );
        return;
      }
    }

    if (haySolapamiento()) return;

    final configs = parciales
        .map(
          (p) => ParcialConfig(
            numero: p.numero,
            fechaInicio: p.fechaInicio,
            fechaFin: p.fechaFin,
          ),
        )
        .toList();

    await LocalStorage.guardarParciales(configs);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Parciales guardados')));

    Navigator.pop(context, true);
  }

  String _fechaVisible(String fecha) {
    if (fecha.isEmpty) return 'Seleccionar';

    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(fecha));
    } catch (_) {
      return fecha;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar parciales'),
        automaticallyImplyLeading: !widget.obligatorio,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF01152E), Color(0xFF17325C)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parciales del semestre',
                  style: TextStyle(
                    color: Color(0xFFE3C076),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Defina el rango de fechas para que la app calcule automáticamente el parcial en cada asistencia.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            initialValue: cantidadParciales,
            decoration: InputDecoration(
              labelText: 'Cantidad de parciales',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 parcial')),
              DropdownMenuItem(value: 2, child: Text('2 parciales')),
              DropdownMenuItem(value: 3, child: Text('3 parciales')),
              DropdownMenuItem(value: 4, child: Text('4 parciales')),
              DropdownMenuItem(value: 5, child: Text('5 parciales')),
            ],
            onChanged: (value) {
              if (value != null) cambiarCantidad(value);
            },
          ),
          const SizedBox(height: 18),
          ...List.generate(parciales.length, (i) {
            final p = parciales[i];

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${p.numero}',
                            style: const TextStyle(
                              color: Color(0xFF01152E),
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Parcial ${p.numero}',
                        style: const TextStyle(
                          color: Color(0xFF01152E),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _FechaButton(
                          titulo: 'Inicio',
                          fecha: _fechaVisible(p.fechaInicio),
                          icon: Icons.calendar_month,
                          onTap: () => seleccionarFecha(index: i, inicio: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FechaButton(
                          titulo: 'Fin',
                          fecha: _fechaVisible(p.fechaFin),
                          icon: Icons.event_available,
                          onTap: () =>
                              seleccionarFecha(index: i, inicio: false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: guardar,
              icon: const Icon(Icons.save),
              label: const Text('Guardar parciales'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FechaButton extends StatelessWidget {
  final String titulo;
  final String fecha;
  final IconData icon;
  final VoidCallback onTap;

  const _FechaButton({
    required this.titulo,
    required this.fecha,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vacio = fecha == 'Seleccionar';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: vacio ? const Color(0xFFE5E7EB) : const Color(0xFFE3C076),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: vacio ? const Color(0xFF5B6573) : const Color(0xFFA6894B),
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              titulo,
              style: const TextStyle(color: Color(0xFF5B6573), fontSize: 11),
            ),
            const SizedBox(height: 3),
            Text(
              fecha,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: vacio
                    ? const Color(0xFF5B6573)
                    : const Color(0xFF01152E),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParcialTemp {
  final int numero;
  String fechaInicio;
  String fechaFin;

  _ParcialTemp({
    required this.numero,
    this.fechaInicio = '',
    this.fechaFin = '',
  });
}
