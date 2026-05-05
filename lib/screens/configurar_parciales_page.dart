import 'package:flutter/material.dart';

class ConfigurarParcialesPage extends StatelessWidget {
  final bool obligatorio;

  const ConfigurarParcialesPage({super.key, this.obligatorio = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parciales')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'La configuración de parciales fue eliminada.\n\nAhora el parcial se selecciona al iniciar cada sesión de asistencia.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
