import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/modelos/historial_modelos.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';

class CanalesValidacionOperativo extends StatelessWidget {
  const CanalesValidacionOperativo({super.key, required this.resumen});

  final ResumenHistorialApp resumen;

  @override
  Widget build(BuildContext context) {
    final total = resumen.qr + resumen.manuales;
    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.hub_outlined,
                    color: ColoresUbb.azulApp,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Origen de validaciones',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: ColoresUbb.azulNoche,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  Text(
                    '$total total',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColoresUbb.textoSecundario,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              BarraCanalValidacion(
                etiqueta: 'QR',
                valor: resumen.qr,
                total: total,
                icono: Icons.qr_code_2_outlined,
                color: ColoresUbb.azulApp,
              ),
              const SizedBox(height: 10),
              BarraCanalValidacion(
                etiqueta: 'Manual',
                valor: resumen.manuales,
                total: total,
                icono: Icons.edit_note_outlined,
                color: ColoresUbb.turquesa,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BarraCanalValidacion extends StatelessWidget {
  const BarraCanalValidacion({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.total,
    required this.icono,
    required this.color,
  });

  final String etiqueta;
  final int valor;
  final int total;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final proporcion =
        total == 0 ? 0.0 : (valor / total).clamp(0.0, 1.0).toDouble();
    final porcentaje = (proporcion * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icono, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                etiqueta,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ColoresUbb.azulNoche,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Text(
              '$valor · $porcentaje%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColoresUbb.textoSecundario,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: proporcion,
            minHeight: 7,
            color: color,
            backgroundColor: ColoresUbb.borde,
          ),
        ),
      ],
    );
  }
}

class EstadoBicicleterosOperativo extends StatelessWidget {
  const EstadoBicicleterosOperativo({
    super.key,
    required this.bicicleteros,
    this.onVerDetalle,
  });

  final List<BicicleteroApp> bicicleteros;
  final VoidCallback? onVerDetalle;

  @override
  Widget build(BuildContext context) {
    final ordenados = [...bicicleteros]
      ..sort((a, b) => b.porcentajeUso.compareTo(a.porcentajeUso));
    final visibles = ordenados.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: TituloApartado(titulo: 'Estado de bicicleteros'),
            ),
            if (onVerDetalle != null)
              TextButton(
                onPressed: onVerDetalle,
                child: const Text('Ver detalle'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (visibles.isEmpty)
          const EstadoLista(
            icono: Icons.location_off_outlined,
            titulo: 'Sin bicicleteros activos',
            detalle: 'Habilita bicicleteros desde configuración.',
          )
        else
          ...visibles.map(
            (bicicletero) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaBicicleteroOperativa(bicicletero: bicicletero),
            ),
          ),
      ],
    );
  }
}

class TarjetaBicicleteroOperativa extends StatelessWidget {
  const TarjetaBicicleteroOperativa({super.key, required this.bicicletero});

  final BicicleteroApp bicicletero;

  @override
  Widget build(BuildContext context) {
    final uso = (bicicletero.porcentajeUso / 100).clamp(0.0, 1.0);
    final sinCupos = bicicletero.cuposDisponibles == 0;
    final pocosCupos = bicicletero.cuposDisponibles <= 5;
    final color = sinCupos || uso >= 0.9
        ? ColoresUbb.rojoInstitucional
        : uso >= 0.75 || pocosCupos
            ? ColoresUbb.amarilloInstitucional
            : ColoresUbb.exito;
    final estado = sinCupos
        ? 'Sin cupos'
        : uso >= 0.9 || bicicletero.cuposDisponibles <= 2
            ? 'Crítico'
            : uso >= 0.75 || pocosCupos
                ? 'Atención'
                : 'Normal';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.location_on_outlined, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bicicletero.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: ColoresUbb.azulNoche,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        '${bicicletero.cuposDisponibles} cupos disponibles',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ColoresUbb.textoSecundario,
                            ),
                      ),
                    ],
                  ),
                ),
                ChipEstado(texto: estado, color: color),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: uso,
                minHeight: 8,
                color: color,
                backgroundColor: ColoresUbb.borde,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: Text(
                  '${bicicletero.ocupados}/${bicicletero.capacidad} ocupados',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColoresUbb.textoSecundario,
                        fontWeight: FontWeight.w700,
                      ),
                )),
                const SizedBox(width: 8),
                Text(
                  '${bicicletero.porcentajeUso}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
