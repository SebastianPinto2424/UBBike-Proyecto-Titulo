import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/historial/application/resumen_guardias.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/widgets/tarjeta_movimiento.dart';

String detalleResumenGuardia(ResumenGuardia resumen) {
  final bicicleteros = resumen.bicicleteros.toList()..sort();
  final visibles = bicicleteros.take(2).join(', ');
  final restantes = bicicleteros.length - 2;
  final detalleBicicleteros =
      restantes > 0 ? '$visibles y $restantes más' : visibles;

  return [
    '${resumen.total} validaciones',
    '${resumen.denegaciones} denegaciones',
    if (detalleBicicleteros.isNotEmpty) detalleBicicleteros,
  ].join(' | ');
}

void mostrarDetalleGuardia(
  BuildContext context,
  String nombre,
  ResumenGuardia resumen,
  List<MovimientoApp> movimientos,
) {
  final ordenados = [...movimientos]
    ..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
  final double alturaInicial =
      (0.42 + ordenados.length * 0.12).clamp(0.42, 0.9).toDouble();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: alturaInicial,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Operaciones de $nombre',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            detalleResumenGuardia(resumen),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ColoresUbb.textoSecundario,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 14),
          ...ordenados.map(
            (movimiento) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaMovimientoCentral(
                movimiento: movimiento,
                mostrarIdentidad: true,
                mostrarGuardia: false,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
