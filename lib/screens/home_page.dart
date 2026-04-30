import 'package:flutter/material.dart';
import '../services/exportador_csv.dart';
import '../services/local_storage.dart';
import 'configurar_parciales_page.dart';
import 'estadisticas_grupos_page.dart';
import 'scanner_page.dart';
import 'ver_asistencias_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int totalSesiones = 0;
  int totalRegistros = 0;
  bool revisadoConfig = false;
  @override
  void initState() {
    super.initState();
    iniciar();
  }

  Future<void> iniciar() async {
    await verificarConfiguracion();
    await cargarResumen();
  }

  Future<void> verificarConfiguracion() async {
    final configurado = await LocalStorage.parcialesConfigurados();
    if (!configurado && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ConfigurarParcialesPage(obligatorio: true),
        ),
      );
    }
    revisadoConfig = true;
  }

  Future<void> cargarResumen() async {
    final sesiones = await LocalStorage.contarSesiones();
    final registros = await LocalStorage.contarRegistros();
    if (!mounted) return;
    setState(() {
      totalSesiones = sesiones;
      totalRegistros = registros;
    });
  }

  Future<void> irAsistencia() async {
    if (!revisadoConfig) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ScannerPage(tipoRegistro: 'asistencia', fechaClase: DateTime.now()),
      ),
    );
    await cargarResumen();
  }

  Future<void> irVerAsistencias() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VerAsistenciasPage()),
    );
    await cargarResumen();
  }

  Future<void> irEstadisticas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EstadisticasGruposPage()),
    );
    await cargarResumen();
  }

  Future<void> exportarCsv() async {
    final path = await ExportadorCsv.exportarYCompartir();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null
              ? 'No hay registros para exportar'
              : 'CSV generado correctamente',
        ),
      ),
    );
  }

  Future<void> abrirConfiguracion() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConfigurarParcialesPage()),
    );
    await cargarResumen();
  }

  Future<void> borrarRegistros() async {
    if (totalRegistros == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para eliminar')),
      );
      return;
    }
    String textoConfirmacion = '';
    bool habilitarBoton = false;
    final confirmacion = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                'Borrar registros',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF01152E),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Se eliminarán TODOS los registros guardados.\n'
                    'Esta acción no se puede deshacer.\n\n'
                    'Escribe ELIMINAR para continuar.',
                    style: TextStyle(color: Color(0xFF5B6573), fontSize: 15),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    autofocus: true,
                    onChanged: (value) {
                      textoConfirmacion = value;
                      final nuevoEstado =
                          textoConfirmacion.trim().toUpperCase() == 'ELIMINAR';
                      if (nuevoEstado != habilitarBoton) {
                        setDialogState(() {
                          habilitarBoton = nuevoEstado;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Confirmación',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Color(0xFF5B6573),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: habilitarBoton
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD93025),
                    foregroundColor: Colors.white,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Eliminar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmacion != true) return;
    await LocalStorage.borrarTodosLosRegistros();
    await cargarResumen();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Todos los registros fueron eliminados')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hayRegistros = totalRegistros > 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de asistencia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: abrirConfiguracion,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
              child: Column(
                children: [
                  const Text(
                    'Sesiones registradas',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$totalSesiones',
                    style: const TextStyle(
                      color: Color(0xFFE3C076),
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _HomeActionCard(
              icon: Icons.qr_code_scanner,
              title: 'Tomar asistencia',
              subtitle: 'Registrar una nueva sesión escaneando códigos QR.',
              onTap: irAsistencia,
            ),
            const SizedBox(height: 12),
            _HomeActionCard(
              icon: Icons.list_alt,
              title: 'Ver asistencias',
              subtitle: 'Consultar sesiones anteriores y justificar alumnos.',
              onTap: hayRegistros ? irVerAsistencias : null,
            ),
            const SizedBox(height: 12),
            _HomeActionCard(
              icon: Icons.bar_chart,
              title: 'Ver estadísticas por grupo',
              subtitle:
                  'Consultar asistencias, faltas y porcentajes por parcial.',
              onTap: hayRegistros ? irEstadisticas : null,
            ),
            const SizedBox(height: 12),
            _HomeActionCard(
              icon: Icons.upload_file,
              title: 'Exportar CSV',
              subtitle: 'Generar archivo CSV con todos los registros.',
              onTap: hayRegistros ? exportarCsv : null,
            ),
            const SizedBox(height: 12),
            _HomeActionCard(
              icon: Icons.delete_forever,
              title: 'Borrar registros',
              subtitle: 'Eliminar todas las asistencias guardadas.',
              onTap: hayRegistros ? borrarRegistros : null,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: danger
                        ? const Color(0xFFFFF1F0)
                        : const Color(0xFFFFF8E8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: danger
                        ? const Color(0xFFD93025)
                        : const Color(0xFF01152E),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF01152E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5B6573),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF01152E)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
