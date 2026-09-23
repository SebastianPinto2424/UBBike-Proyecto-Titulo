import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/providers/conexion_provider.dart';
import 'package:ubbike/features/incidencias/application/incidencias_vm.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/historial/data/historial_modelos.dart';
import 'package:ubbike/features/inicio/application/dashboard_central_vm.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/shared/widgets/central_widgets.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/utils/utiles_comun.dart';

class EstadoInicioOperativo extends StatelessWidget {
  const EstadoInicioOperativo(
      {super.key, required this.datos, this.sobreOscuro = false});
  final DatosDashboardCentral? datos;
  final bool sobreOscuro;
  @override
  Widget build(BuildContext context) => Text(
        datos == null
            ? 'Consultando disponibilidad…'
            : '${datos!.cuposDisponiblesTotal} cupos disponibles en el campus',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: sobreOscuro ? Colors.white70 : ColoresUbb.textoSecundario),
      );
}

class PanelDashboardOperativoCargando extends StatelessWidget {
  const PanelDashboardOperativoCargando({
    super.key,
    required this.periodo,
    required this.onPeriodo,
  });

  final String periodo;
  final ValueChanged<String> onPeriodo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(
          height: 96,
          child: Center(child: CircularProgressIndicator()),
        ),
        SelectorPeriodoDashboard(
          seleccionado: periodo,
          onChange: onPeriodo,
        ),
        const SizedBox(height: 12),
        const GridIndicadoresCentral(
          indicadores: [
            IndicadorCentral(
              valor: '-',
              etiqueta: 'Movimientos',
              icono: Icons.swap_horiz_outlined,
              colorIcono: ColoresUbb.azulApp,
            ),
            IndicadorCentral(
              valor: '-',
              etiqueta: 'Denegados',
              icono: Icons.block_outlined,
              colorIcono: ColoresUbb.rojoInstitucional,
            ),
            IndicadorCentral(
              valor: '-',
              etiqueta: 'Incidencias',
              icono: Icons.report_problem_outlined,
              colorIcono: ColoresUbb.amarilloInstitucional,
            ),
          ],
        ),
      ],
    );
  }
}

class EstadoCampusOperativo extends StatelessWidget {
  const EstadoCampusOperativo({super.key, required this.datos});

  final DatosDashboardCentral datos;

  @override
  Widget build(BuildContext context) {
    final uso = datos.usoCampus;
    final porcentaje = (uso * 100).round();
    final color = uso >= 0.9
        ? ColoresUbb.rojoInstitucional
        : uso >= 0.75
            ? ColoresUbb.amarilloInstitucional
            : ColoresUbb.exito;
    final detalle = datos.capacidadTotal == 0
        ? 'Sin capacidad configurada'
        : '${datos.cuposDisponiblesTotal} cupos disponibles';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_city_outlined,
                    color: color,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Capacidad del campus',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: ColoresUbb.azulNoche,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detalle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ColoresUbb.textoSecundario,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$porcentaje%',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: uso,
                minHeight: 9,
                color: color,
                backgroundColor: ColoresUbb.borde,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PanelAtencionOperativa extends ConsumerWidget {
  const PanelAtencionOperativa(
      {super.key,
      required this.datos,
      this.onAbrirMovimientos,
      this.onAbrirGuardias,
      this.onAbrirSolicitudes,
      this.onAbrirIncidencias});
  final DatosDashboardCentral datos;
  final VoidCallback? onAbrirMovimientos;
  final VoidCallback? onAbrirGuardias;
  final VoidCallback? onAbrirSolicitudes;
  final VoidCallback? onAbrirIncidencias;

  void _abrirIncidencias(BuildContext context, WidgetRef ref) {
    final sub = ProviderScope.containerOf(context, listen: false)
        .listen(filtrosIncidenciasProvider, (_, __) {});
    ref.read(filtrosIncidenciasProvider.notifier).state =
        const FiltrosIncidencias(estado: 'ABIERTAS');
    onAbrirIncidencias!();
    WidgetsBinding.instance.addPostFrameCallback((_) => sub.close());
  }

  Widget _solicitudesPendientes() => AlertaOperativa(
      icono: Icons.campaign_outlined,
      titulo: 'Solicitudes de guardia',
      valor: datos.totalSolicitudesAbiertas,
      detalle: 'Usuarios esperando atención',
      color: ColoresUbb.azulApp,
      onTap: onAbrirSolicitudes);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conexion = ref.watch(conexionProvider);
    final incidencias = datos.totalIncidenciasAbiertas;
    final actualizado = datos.actualizadoEn;
    final estado = datos.desactualizado
        ? 'No pudimos actualizar. Se muestran los últimos datos.'
        : conexion == EstadoConexion.conectado
            ? 'Conectado · actualización automática'
            : 'Sin conexión en vivo · consulta cada 30 s';
    if (incidencias == 0) {
      final conectado = conexion == EstadoConexion.conectado;
      final detalle = datos.desactualizado
          ? estado
          : conectado
              ? 'En vivo · actualización automática'
              : estado;
      return Card(
          key: const Key('incidencias-sin-pendientes'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Icon(
                        datos.desactualizado
                            ? Icons.info_outline
                            : Icons.check_circle_outline,
                        color: datos.desactualizado
                            ? ColoresUbb.amarilloInstitucional
                            : ColoresUbb.exito),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              datos.desactualizado
                                  ? 'Último registro: sin incidencias'
                                  : 'Sin incidencias abiertas',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Semantics(
                              liveRegion: true,
                              child: Text(
                                  '$detalle${actualizado == null ? '' : ' · Última consulta: ${formatearHora(actualizado)}'}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: ColoresUbb.textoSecundario))),
                        ])),
                    if (onAbrirIncidencias != null)
                      IconButton(
                          tooltip: 'Ver incidencias abiertas',
                          onPressed: () => _abrirIncidencias(context, ref),
                          icon: const Icon(Icons.chevron_right,
                              color: ColoresUbb.azulApp)),
                  ]),
                  if (datos.totalSolicitudesAbiertas > 0) ...[
                    const Divider(),
                    _solicitudesPendientes(),
                  ],
                ]),
          ));
    }
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.report_problem_outlined,
                  color: incidencias > 0
                      ? ColoresUbb.amarilloInstitucional
                      : ColoresUbb.exito),
              Text('Incidencias',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              ChipEstado(
                  texto: '$incidencias abiertas',
                  color: incidencias > 0
                      ? ColoresUbb.amarilloInstitucional
                      : ColoresUbb.exito),
            ]),
        const SizedBox(height: 8),
        Semantics(
            liveRegion: true,
            child: Text(
                '$estado${actualizado == null ? '' : '\nÚltima consulta: ${formatearHora(actualizado)}'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: ColoresUbb.textoSecundario))),
        const Divider(height: 24),
        ...datos.incidenciasAbiertas.take(3).map((item) {
          final minutos = DateTime.now()
              .difference(item.creadaEn)
              .inMinutes
              .clamp(0, 9999999);
          final edad = minutos < 1
              ? 'Ahora'
              : minutos < 60
                  ? 'Hace $minutos min'
                  : minutos < 1440
                      ? 'Hace ${minutos ~/ 60} h'
                      : 'Hace ${minutos ~/ 1440} d';
          return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.bicicletero.nombre,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(item.descripcion,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                        '${item.estado == 'EN_REVISION' ? 'En revisión' : 'Pendiente'} · $edad',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: ColoresUbb.textoSecundario)),
                  ]));
        }),
        if (onAbrirIncidencias != null)
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: () => _abrirIncidencias(context, ref),
                  label: const Text('Ver abiertas'),
                  icon: const Icon(Icons.arrow_forward, size: 18))),
        if (datos.totalSolicitudesAbiertas > 0) ...[
          const Divider(),
          _solicitudesPendientes(),
        ],
      ]),
    ));
  }
}

class AlertaOperativa extends StatelessWidget {
  const AlertaOperativa({
    super.key,
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.color,
    this.onTap,
  });

  final IconData icono;
  final String titulo;
  final int valor;
  final String detalle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icono, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ColoresUbb.azulNoche,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColoresUbb.textoSecundario,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Text(
                '$valor',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                color: ColoresUbb.textoSecundario,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MetricasDashboardOperativo extends StatelessWidget {
  const MetricasDashboardOperativo({super.key, required this.datos});

  final DatosDashboardCentral datos;

  @override
  Widget build(BuildContext context) {
    final resumen = datos.resumen;
    return GridIndicadoresCentral(
      indicadores: [
        IndicadorCentral(
          valor: resumen.totalMovimientos.toString(),
          etiqueta: 'Movimientos',
          icono: Icons.swap_horiz_outlined,
          colorIcono: ColoresUbb.azulApp,
        ),
        IndicadorCentral(
          valor: resumen.ingresos.toString(),
          etiqueta: 'Ingresos',
          icono: Icons.login_outlined,
          colorIcono: ColoresUbb.exito,
        ),
        IndicadorCentral(
          valor: resumen.retiros.toString(),
          etiqueta: 'Retiros',
          icono: Icons.logout_outlined,
          colorIcono: ColoresUbb.azulApp,
        ),
        IndicadorCentral(
          valor: resumen.denegados.toString(),
          etiqueta: 'Denegados',
          icono: Icons.block_outlined,
          colorIcono: ColoresUbb.rojoInstitucional,
        ),
        IndicadorCentral(
          valor: datos.totalSolicitudesAbiertas.toString(),
          etiqueta: 'Solicitudes',
          icono: Icons.campaign_outlined,
          colorIcono: ColoresUbb.turquesa,
        ),
        IndicadorCentral(
          valor: datos.totalIncidenciasAbiertas.toString(),
          etiqueta: 'Incidencias',
          icono: Icons.report_problem_outlined,
          colorIcono: ColoresUbb.amarilloInstitucional,
        ),
      ],
    );
  }
}

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
    this.onVerGuardias,
  });

  final List<BicicleteroApp> bicicleteros;
  final VoidCallback? onVerGuardias;

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
            if (onVerGuardias != null)
              TextButton(
                onPressed: onVerGuardias,
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
              maxItems: 3,
            );
            final bicicleteros = RankingResumenOperativo(
              titulo: 'Operaciones por bicicletero',
              datos: resumen.operacionesPorBicicletero,
              icono: Icons.location_on_outlined,
              maxItems: 3,
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
    this.maxItems = 5,
  });

  final String titulo;
  final Map<String, int> datos;
  final IconData icono;
  final int maxItems;

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
              ...entradas.take(maxItems).map(
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
