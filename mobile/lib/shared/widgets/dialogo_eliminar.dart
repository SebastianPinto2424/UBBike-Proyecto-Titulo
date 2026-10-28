import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/widgets/botones_accion.dart';
import 'package:ubbike/shared/widgets/dialogo_accion.dart';

Future<bool> confirmarEliminacion(
  BuildContext context, {
  required String titulo,
  required String nombre,
  required String consecuencia,
  String etiquetaConfirmar = 'Eliminar',
  IconData icono = Icons.delete_forever_outlined,
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) {
      final tema = Theme.of(context);

      return DialogoAccion(
        icono: icono,
        colorIcono: ColoresUbb.rojoInstitucional,
        titulo: titulo,
        contenido: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ColoresUbb.superficieAzul,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ColoresUbb.borde),
              ),
              child: Text(
                nombre,
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: ColoresUbb.azulNoche,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              consecuencia,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: ColoresUbb.textoSecundario),
            ),
          ],
        ),
        acciones: BotonesAccion.confirmacion(
          destructiva: true,
          textoConfirmar: etiquetaConfirmar,
          claveCancelar: const Key('eliminar-cancelar'),
          claveConfirmar: const Key('eliminar-confirmar'),
          onCancelar: () => Navigator.pop(context, false),
          onConfirmar: () => Navigator.pop(context, true),
        ),
      );
    },
  );

  return confirmado == true;
}
