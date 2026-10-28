import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/widgets/botones_accion.dart';

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
    this.secundarioCancela = false,
  });

  final bool esIngreso;
  final bool procesando;
  final bool habilitado;
  final VoidCallback onConfirmar;
  final VoidCallback onRechazar;
  final String textoSecundario;
  final IconData iconoSecundario;
  final VoidCallback onSecundario;
  final bool secundarioCancela;

  @override
  Widget build(BuildContext context) {
    final operacion = esIngreso ? 'ingreso' : 'retiro';
    final activo = habilitado && !procesando;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        BotonesAccion(
          secundaria: AccionBoton(
            texto: 'Rechazar $operacion',
            color: ColoresUbb.rojoInstitucional,
            icono: Icons.block,
            onPressed: activo ? onRechazar : null,
          ),
          principal: AccionBoton(
            texto: 'Confirmar $operacion',
            color: ColoresUbb.azulApp,
            icono: Icons.check_circle_outline,
            cargando: procesando,
            onPressed: activo ? onConfirmar : null,
          ),
        ),
        const SizedBox(height: 8),
        if (secundarioCancela)
          BotonAccion(
            accion: AccionBoton(
              texto: textoSecundario,
              color: ColoresUbb.rojoInstitucional,
              icono: iconoSecundario,
              onPressed: procesando ? null : onSecundario,
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: procesando ? null : onSecundario,
            icon: Icon(iconoSecundario),
            label: Text(textoSecundario),
          ),
      ],
    );
  }
}
