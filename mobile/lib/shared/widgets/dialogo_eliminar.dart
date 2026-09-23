import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';

Future<bool> confirmarEliminacion(
  BuildContext context, {
  required String titulo,
  required String nombre,
  required String consecuencia,
  String etiquetaConfirmar = 'Eliminar',
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) {
      final tema = Theme.of(context);

      return AlertDialog(
        icon: const Icon(
          Icons.delete_forever_outlined,
          color: ColoresUbb.rojoInstitucional,
          size: 44,
        ),
        title: Text(titulo, textAlign: TextAlign.center),
        content: Column(
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
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('eliminar-cancelar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresUbb.azulApp,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Cancelar'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const Key('eliminar-confirmar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresUbb.rojoInstitucional,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(etiquetaConfirmar),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );

  return confirmado == true;
}
