import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/historial_modelos.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/utilidades/utiles_comun.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';

class ActividadPeriodoOperativo extends StatelessWidget {
  const ActividadPeriodoOperativo({super.key, required this.resumen});

  final ResumenHistorialApp resumen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloApartado(titulo: 'Actividad del periodo'),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final guardias = RankingResumenOperativo(
              titulo: 'Operaciones por guardia',
              datos: resumen.operacionesPorGuardia,
              icono: Icons.security_outlined,
              maximoElementos: 3,
            );
            final bicicleteros = RankingResumenOperativo(
              titulo: 'Operaciones por bicicletero',
              datos: resumen.operacionesPorBicicletero,
              icono: Icons.location_on_outlined,
              maximoElementos: 3,
            );

            if (constraints.maxWidth >= 720) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: guardias),
                  const SizedBox(width: 10),
                  Expanded(child: bicicleteros),
                ],
              );
            }

            return Column(
              children: [
                guardias,
                const SizedBox(height: 10),
                bicicleteros,
              ],
            );
          },
        ),
      ],
    );
  }
}

class ActividadRecienteOperativo extends StatelessWidget {
  const ActividadRecienteOperativo({
    super.key,
    required this.movimientos,
    this.onVerMovimientos,
  });

  final List<MovimientoApp> movimientos;
  final VoidCallback? onVerMovimientos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: TituloApartado(titulo: 'Actividad reciente'),
            ),
            if (onVerMovimientos != null)
              TextButton(
                onPressed: onVerMovimientos,
                child: const Text('Ver historial'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (movimientos.isEmpty)
          const EstadoLista(
            icono: Icons.history_outlined,
            titulo: 'Sin actividad reciente',
            detalle: 'No hay movimientos registrados hoy.',
          )
        else
          ...movimientos.map(
            (movimiento) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MovimientoRecienteCompacto(movimiento: movimiento),
            ),
          ),
      ],
    );
  }
}

class MovimientoRecienteCompacto extends StatelessWidget {
  const MovimientoRecienteCompacto({super.key, required this.movimiento});

  final MovimientoApp movimiento;

  @override
  Widget build(BuildContext context) {
    final esIngreso = movimiento.tipo == 'INGRESO';
    final confirmado = movimiento.estado == 'CONFIRMADO';
    final color = confirmado ? ColoresUbb.exito : ColoresUbb.rojoInstitucional;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              esIngreso ? Icons.login_outlined : Icons.logout_outlined,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${esIngreso ? 'Ingreso' : 'Retiro'} | ${movimiento.usuarioNombre}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ColoresUbb.azulNoche,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${movimiento.bicicleteroNombre} · ${formatearHora(movimiento.creadoEn)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColoresUbb.textoSecundario,
                        ),
                  ),
                ],
              ),
            ),
            ChipEstado(
              texto: confirmado ? 'Confirmado' : 'Denegado',
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class RankingResumenOperativo extends StatelessWidget {
  const RankingResumenOperativo({
    super.key,
    required this.titulo,
    required this.datos,
    required this.icono,
    this.maximoElementos = 5,
  });

  final String titulo;
  final Map<String, int> datos;
  final IconData icono;
  final int maximoElementos;

  @override
  Widget build(BuildContext context) {
    final entradas = datos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maximo = entradas.isEmpty ? 1 : entradas.first.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: ColoresUbb.azulApp),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (entradas.isEmpty)
              Text(
                'Sin datos para el filtro seleccionado.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ColoresUbb.textoSecundario,
                    ),
              )
            else
              ...entradas.take(maximoElementos).map(
                    (entrada) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entrada.key,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Text(
                                entrada.value.toString(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: entrada.value / maximo,
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(8),
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
