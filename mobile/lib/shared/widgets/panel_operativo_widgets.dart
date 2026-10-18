import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/dashboard_modelos.dart';
import 'package:ubbike/shared/widgets/central_widgets.dart';

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
