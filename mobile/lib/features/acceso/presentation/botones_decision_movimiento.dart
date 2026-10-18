import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';

class BotonesDecisionMovimiento extends StatelessWidget {
  const BotonesDecisionMovimiento({
    super.key,
    required this.esIngreso,
    required this.procesando,
    required this.habilitado,
    required this.onConfirmar,
    required this.onRechazar,
    required this.textoSecundario,
    required this.iconoSecundario,
    required this.onSecundario,
  });

  final bool esIngreso;
  final bool procesando;
  final bool habilitado;
  final VoidCallback onConfirmar;
  final VoidCallback onRechazar;
  final String textoSecundario;
  final IconData iconoSecundario;
  final VoidCallback onSecundario;

  @override
  Widget build(BuildContext context) {
    final operacion = esIngreso ? 'ingreso' : 'retiro';
    final activo = habilitado && !procesando;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: activo ? onConfirmar : null,
                icon: procesando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Confirmar $operacion'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColoresUbb.rojoInstitucional,
                  side: const BorderSide(color: ColoresUbb.rojoInstitucional),
                ),
                onPressed: activo ? onRechazar : null,
                icon: const Icon(Icons.block),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Rechazar $operacion'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: procesando ? null : onSecundario,
          icon: Icon(iconoSecundario),
          label: Text(textoSecundario),
        ),
      ],
    );
  }
}
