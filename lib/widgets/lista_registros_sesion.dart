import 'package:flutter/material.dart';

import '../models/registro_asistencia.dart';

class ListaRegistrosSesion extends StatelessWidget {
  final List<RegistroAsistencia> registrosSesion;
  final Function(RegistroAsistencia)? onEliminar;

  const ListaRegistrosSesion({
    super.key,
    required this.registrosSesion,
    this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    if (registrosSesion.isEmpty) {
      return const Center(
        child: Text(
          'No hay registros aún',
          style: TextStyle(color: Color(0xFF5B6573)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: registrosSesion.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final r = registrosSesion[i];

        final esJustificada = r.tipoRegistro.toLowerCase() == 'justificada';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: esJustificada
                      ? const Color(0xFFFFF8E8) // amarillo
                      : const Color(0xFFEAF7EE), // verde asistencia
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person,
                  color: esJustificada
                      ? const Color(0xFF8A6B20) // tono dorado
                      : const Color(0xFF1E8E3E), // verde fuerte
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF01152E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Matrícula: ${r.matricula}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5B6573),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _chipTipo(
                          esJustificada ? 'Justificada' : 'Asistencia',
                          esJustificada: esJustificada,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _hora(r.fechaHoraEscaneo),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF01152E),
                    ),
                  ),
                  if (onEliminar != null) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => onEliminar!(r),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Color(0xFFD93025),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chipTipo(String text, {required bool esJustificada}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: esJustificada
            ? const Color(0xFFFFF8E8)
            : const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: esJustificada
              ? const Color(0xFF8A6B20)
              : const Color(0xFF1E8E3E),
        ),
      ),
    );
  }

  String _hora(String fechaHora) {
    if (fechaHora.length >= 16) {
      return fechaHora.substring(11, 16);
    }
    return '--:--';
  }
}
