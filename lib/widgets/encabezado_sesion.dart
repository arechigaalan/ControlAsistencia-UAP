import 'package:flutter/material.dart';
import '../models/session_data.dart';
import '../services/utils_fechas.dart';

class EncabezadoSesion extends StatelessWidget {
  final SessionData? sesion;
  final DateTime fechaClase;
  final int capturados;
  final String grupoSesion;
  final String turnoSesion;
  final String plantelSesion;
  final String horaSesion;

  const EncabezadoSesion({
    super.key,
    required this.sesion,
    required this.fechaClase,
    required this.capturados,
    required this.grupoSesion,
    required this.turnoSesion,
    required this.plantelSesion,
    required this.horaSesion,
  });

  @override
  Widget build(BuildContext context) {
    if (sesion == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.blue.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fecha de la sesión: ${UtilsFechas.fechaHumana(fechaClase)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Hora de la sesión: ${horaSesion.isEmpty ? '—' : horaSesion}'),
          Text('Plantel: ${plantelSesion.isEmpty ? '—' : plantelSesion}'),
          Text('Grupo: ${grupoSesion.isEmpty ? '—' : grupoSesion}'),
          Text('Turno: ${turnoSesion.isEmpty ? '—' : turnoSesion}'),
          const SizedBox(height: 4),
          Text(
            'Alumnos registrados: $capturados',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}