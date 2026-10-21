import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';

class DialogoAccion extends StatelessWidget {
  const DialogoAccion({
    super.key,
    required this.titulo,
    required this.contenido,
    required this.acciones,
    this.icono,
    this.colorIcono = ColoresUbb.azulApp,
  });

  final String titulo;
  final Widget contenido;
  final Widget acciones;
  final IconData? icono;
  final Color colorIcono;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final icono = this.icono;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icono != null) ...[
                Icon(icono, color: colorIcono, size: 44),
                const SizedBox(height: 12),
              ],
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: tema.textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              DefaultTextStyle.merge(
                style: tema.textTheme.bodyMedium,
                child: contenido,
              ),
              const SizedBox(height: 20),
              acciones,
            ],
          ),
        ),
      ),
    );
  }
}
