import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';

const _duracionAviso = Duration(milliseconds: 1600);

Future<void> avisarMovimientoRegistrado(
  BuildContext context, {
  required bool confirmado,
  required bool esIngreso,
  required String persona,
  VoidCallback? alTerminar,
}) async {
  unawaited(
    confirmado ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact(),
  );
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => _DialogoResultadoMovimiento(
      confirmado: confirmado,
      esIngreso: esIngreso,
      persona: persona,
      irAlHistorial: alTerminar != null,
    ),
  );
  alTerminar?.call();
}

class _DialogoResultadoMovimiento extends StatefulWidget {
  const _DialogoResultadoMovimiento({
    required this.confirmado,
    required this.esIngreso,
    required this.persona,
    required this.irAlHistorial,
  });

  final bool confirmado;
  final bool esIngreso;
  final String persona;
  final bool irAlHistorial;

  @override
  State<_DialogoResultadoMovimiento> createState() =>
      _DialogoResultadoMovimientoState();
}

class _DialogoResultadoMovimientoState
    extends State<_DialogoResultadoMovimiento> {
  Timer? _cierre;

  @override
  void initState() {
    super.initState();
    _cierre = Timer(_duracionAviso, () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _cierre?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operacion = widget.esIngreso ? 'Ingreso' : 'Retiro';
    final color =
        widget.confirmado ? ColoresUbb.exito : ColoresUbb.rojoInstitucional;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.confirmado ? Icons.check_circle_outline : Icons.block,
                color: color,
                size: 56,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.confirmado
                  ? '$operacion registrado'
                  : '$operacion rechazado',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.persona,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ColoresUbb.textoSecundario,
                  ),
            ),
            if (widget.irAlHistorial) ...[
              const SizedBox(height: 14),
              Text(
                'Abriendo el historial…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColoresUbb.textoSecundario,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
