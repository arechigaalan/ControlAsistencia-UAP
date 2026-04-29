import 'package:flutter/material.dart';

enum EstadoEscaneo { ninguno, exito, duplicado, error }

class OverlayEstado extends StatelessWidget {
  final EstadoEscaneo estado;
  final String mensaje;
  final String? detalle;

  const OverlayEstado({
    super.key,
    required this.estado,
    required this.mensaje,
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    if (estado == EstadoEscaneo.ninguno) {
      return const SizedBox.shrink();
    }

    final Color color = switch (estado) {
      EstadoEscaneo.exito => Colors.green,
      EstadoEscaneo.error => Colors.red,
      EstadoEscaneo.duplicado => Colors.orange,
      EstadoEscaneo.ninguno => Colors.transparent,
    };

    final IconData icon = switch (estado) {
      EstadoEscaneo.exito => Icons.check_circle,
      EstadoEscaneo.error => Icons.cancel,
      EstadoEscaneo.duplicado => Icons.warning,
      EstadoEscaneo.ninguno => Icons.circle,
    };

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: 1,
      child: Container(
        color: color.withValues(alpha: 0.30),
        child: Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 220),
            tween: Tween(begin: 0.6, end: 1.0),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 310, maxHeight: 250),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 72, color: color),
                      const SizedBox(height: 10),
                      Text(
                        mensaje,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (detalle != null && detalle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 260,
                          child: Text(
                            detalle!,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
