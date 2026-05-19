import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/registro_asistencia.dart';
import '../services/local_storage.dart';
import '../services/turno_helper.dart';
import '../widgets/tarjeta_sesion.dart';
import 'detalle_sesion_page.dart';

class VerAsistenciasPage extends StatefulWidget {
  const VerAsistenciasPage({super.key});

  @override
  State<VerAsistenciasPage> createState() => _VerAsistenciasPageState();
}

class _VerAsistenciasPageState extends State<VerAsistenciasPage> {
  Map<int, Map<String, List<_SesionResumen>>> sesionesPorParcial = {};
  List<int> parcialesOrdenados = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarSesiones();
  }

  ButtonStyle _botonCancelarStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF01152E),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    ),
    minimumSize: const Size(110, 48),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 15,
    ),
  );
}

ButtonStyle _botonEliminarStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFFE3C076),
    foregroundColor: const Color(0xFF01152E),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    ),
    minimumSize: const Size(110, 48),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 15,
    ),
  );
}

  Future<void> cambiarFechaSesion(
  _SesionResumen s,
) async {
  final nuevaFecha = await showDatePicker(
    context: context,
    initialDate: DateTime.tryParse(
          s.fechaClase.replaceAll('/', '-'),
        ) ??
        DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );

  if (nuevaFecha == null) return;

  final fechaTexto = DateFormat(
    'yyyy-MM-dd',
  ).format(nuevaFecha);

  await LocalStorage.actualizarFechaSesionYRegistros(
    sessionId: s.sessionId,
    fechaClase: fechaTexto,
  );

  await cargarSesiones();

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Fecha actualizada'),
    ),
  );
}

  Future<void> mostrarOpcionesSesion(
    _SesionResumen s,
  ) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.calendar_month,
                    color: Color(0xFF01152E),
                  ),
                  title: const Text('Cambiar fecha'),
                  onTap: () {
                    Navigator.pop(sheetContext, 'fecha');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.layers,
                    color: Color(0xFF01152E),
                  ),
                  title: const Text('Cambiar parcial'),
                  onTap: () {
                    Navigator.pop(sheetContext, 'parcial');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Eliminar sesión',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext, 'eliminar');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (accion == null || !mounted) return;

    switch (accion) {
      case 'fecha':
        await cambiarFechaSesion(s);
        break;

      case 'parcial':
        await cambiarParcialSesion(s);
        break;

      case 'eliminar':
        await eliminarSesion(s);
        break;
    }
  }

  Future<void> cambiarParcialSesion(
    _SesionResumen s,
  ) async {
    final parcial = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final numero = index + 1;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFFF8E8),
                    child: Text(
                      '$numero',
                      style: const TextStyle(
                        color: Color(0xFF01152E),
                      ),
                    ),
                  ),
                  title: Text('Parcial $numero'),
                  onTap: () {
                    Navigator.pop(sheetContext, numero);
                  },
                );
              }),
            ),
          ),
        );
      },
    );

    if (parcial == null) return;

    await LocalStorage.actualizarParcialSesionYRegistros(
      sessionId: s.sessionId,
      parcial: parcial,
    );

    await cargarSesiones();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Parcial actualizado'),
      ),
    );
  }

  Future<void> eliminarSesion(
    _SesionResumen s,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text('Eliminar sesión'),
        content: const Text(
          'Esta acción eliminará la sesión y todos sus registros.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: _botonCancelarStyle(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: _botonEliminarStyle(),
              child: const Text('Eliminar'),
            ),
          ],
      ),
    );

    if (confirmar != true) return;

    await LocalStorage.eliminarSesionYRegistros(
      s.sessionId,
    );

    await cargarSesiones();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sesión eliminada'),
      ),
    );
  }

  String _fechaConDia(String fecha) {
  try {
    final partes = fecha.split('/');

    if (partes.length != 3) return fecha;

    final dt = DateTime(
      int.parse(partes[2]),
      int.parse(partes[1]),
      int.parse(partes[0]),
    );

    const dias = [
      'Lun',
      'Mar',
      'Mié',
      'Jue',
      'Vie',
      'Sáb',
      'Dom',
    ];

    final dia = dias[dt.weekday - 1];

    return '$dia $fecha';
  } catch (_) {
    return fecha;
  }
}


  Future<void> cargarSesiones() async {
    final registros = await LocalStorage.obtenerTodosLosRegistros();

    final Map<String, List<RegistroAsistencia>> agrupadas = {};

    for (final r in registros) {
      agrupadas.putIfAbsent(r.sessionId, () => []).add(r);
    }

    final List<_SesionResumen> sesiones = [];

    for (final entry in agrupadas.entries) {
      final registrosSesion = entry.value;

      registrosSesion.sort(
        (a, b) => a.fechaHoraEscaneo.compareTo(b.fechaHoraEscaneo),
      );

      final primero = registrosSesion.first;

      final fechaHora = DateTime.tryParse(
        primero.fechaHoraEscaneo.replaceFirst(' ', 'T'),
      );

      final fechaTexto = fechaHora != null
          ? DateFormat('yyyy-MM-dd').format(fechaHora)
          : primero.fechaClase;

      final fechaVisible = fechaHora != null
          ? DateFormat('dd/MM/yyyy').format(fechaHora)
          : primero.fechaClase;

      final horaTexto =
          fechaHora != null ? DateFormat('HH:mm').format(fechaHora) : '—';

      sesiones.add(
        _SesionResumen(
          sessionId: entry.key,
          plantel: primero.plantel,
          grupo: TurnoHelper.grupoCompleto(
            semestre: primero.semestre,
            grupo: primero.grupo,
          ),
          turno: TurnoHelper.nombreTurno(primero.turno),
          modalidad: TurnoHelper.nombreModalidad(primero.modalidad),
          materiaNombre: primero.materiaNombre,
          fechaClase: primero.fechaClase,
          fechaClave: fechaTexto,
          fechaVisible: fechaVisible,
          hora: horaTexto,
          cantidad: registrosSesion.length,
          parcial: primero.parcial,
          registros: registrosSesion,
        ),
      );
    }

    final Map<int, Map<String, List<_SesionResumen>>> agrupado = {};

    for (final s in sesiones) {
      agrupado.putIfAbsent(s.parcial, () => {});
      agrupado[s.parcial]!.putIfAbsent(s.fechaClave, () => []);
      agrupado[s.parcial]![s.fechaClave]!.add(s);
    }

    final parciales = agrupado.keys.toList()..sort();

    for (final parcial in agrupado.keys) {
      for (final fecha in agrupado[parcial]!.keys) {
        agrupado[parcial]![fecha]!.sort((a, b) {
          final cmpHora = b.hora.compareTo(a.hora);
          if (cmpHora != 0) return cmpHora;
          return b.sessionId.compareTo(a.sessionId);
        });
      }
    }

    if (!mounted) return;

    setState(() {
      sesionesPorParcial = agrupado;
      parcialesOrdenados = parciales;
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

    if (sesionesPorParcial.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No hay sesiones registradas'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistencias'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: parcialesOrdenados.map((parcial) {
          final fechasMap = sesionesPorParcial[parcial]!;
          final fechasOrdenadas = fechasMap.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          final totalSesiones = fechasMap.values.fold<int>(
            0,
            (total, lista) => total + lista.length,
          );

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  collapsedBackgroundColor: const Color(0xFF01152E),
                  backgroundColor: const Color(0xFF01152E),
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white,
                  title: Text(
                    'Parcial $parcial ($totalSesiones sesiones)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: fechasOrdenadas.map((fechaKey) {
                    final sesiones = fechasMap[fechaKey]!;
                    final fechaVisible = sesiones.first.fechaVisible;

                    return Container(
                      color: const Color(0xFFF5F7FA),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              initiallyExpanded: false,
                              collapsedBackgroundColor: Colors.white,
                              backgroundColor: Colors.white,
                              iconColor: const Color(0xFF01152E),
                              collapsedIconColor: const Color(0xFF01152E),
                              title: Text(
                                '${_fechaConDia(fechaVisible)} (${sesiones.length} sesiones)',
                                style: const TextStyle(
                                  color: Color(0xFF01152E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              children: sesiones.map((s) {
                                return TarjetaSesion(
                                  titulo: s.plantel,
                                  subtitulo:
                                      '${s.grupo} | ${s.turno} | ${s.modalidad} | ${s.materiaNombre}',
                                  fecha: s.fechaVisible,
                                  hora: s.hora,
                                  cantidad: s.cantidad,
                                  onLongPress: () async {
                                    await mostrarOpcionesSesion(s);
                                  },

                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DetalleSesionPage(
                                          sessionId: s.sessionId,
                                          fechaClase: s.fechaClase,
                                          parcial: s.parcial,
                                          tituloSesion:
                                              '${s.plantel} | ${s.grupo} | ${s.modalidad} | ${s.materiaNombre} | ${s.fechaVisible}',
                                        ),
                                      ),
                                    );

                                    await cargarSesiones();
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SesionResumen {
  final String sessionId;
  final String plantel;
  final String grupo;
  final String turno;
  final String modalidad;
  final String materiaNombre;
  final String fechaClase;
  final String fechaClave;
  final String fechaVisible;
  final String hora;
  final int cantidad;
  final int parcial;
  final List<RegistroAsistencia> registros;

  _SesionResumen({
    required this.sessionId,
    required this.plantel,
    required this.grupo,
    required this.turno,
    required this.modalidad,
    required this.materiaNombre,
    required this.fechaClase,
    required this.fechaClave,
    required this.fechaVisible,
    required this.hora,
    required this.cantidad,
    required this.parcial,
    required this.registros,
  });
}