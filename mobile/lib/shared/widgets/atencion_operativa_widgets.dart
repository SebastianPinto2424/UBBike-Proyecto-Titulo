import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/conexion_provider.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/dashboard_modelos.dart';
import 'package:ubbike/shared/utils/utiles_comun.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';

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
                          onPressed: onAbrirIncidencias,
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
                  onPressed: onAbrirIncidencias,
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
