import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';

class ResumenGuardiasEnTurno extends StatelessWidget {
  const ResumenGuardiasEnTurno({
    super.key,
    required this.bicicleteros,
    this.onGestionar,
  });

  final List<BicicleteroApp> bicicleteros;
  final VoidCallback? onGestionar;

  @override
  Widget build(BuildContext context) {
    final cubiertos = bicicleteros.where((item) => item.tieneGuardia).length;
    final sinGuardia = bicicleteros.length - cubiertos;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onGestionar,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: ColoresUbb.azulApp),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guardias en turno',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ColoresUbb.azulNoche,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '$cubiertos de ${bicicleteros.length} bicicleteros con guardia',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ColoresUbb.textoSecundario,
                          ),
                    ),
                    if (sinGuardia > 0) ...[
                      const SizedBox(height: 6),
                      ChipEstado(
                        texto: sinGuardia == 1
                            ? '1 sin guardia'
                            : '$sinGuardia sin guardia',
                        color: ColoresUbb.amarilloInstitucional,
                      ),
                    ],
                  ],
                ),
              ),
              if (onGestionar != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onGestionar,
                  child: const Text('Gestionar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
