import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';

class BloqueMensajeSolicitud extends StatelessWidget {
  const BloqueMensajeSolicitud({
    super.key,
    required this.titulo,
    required this.mensaje,
  });

  final String titulo;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ColoresUbb.superficieAzulSuave,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresUbb.azulApp.withValues(alpha: 0.25)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: ColoresUbb.azulApp,
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: textTheme.labelMedium?.copyWith(
                        color: ColoresUbb.azulApp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mensaje,
                      style: textTheme.titleSmall?.copyWith(
                        color: ColoresUbb.azulNoche,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
