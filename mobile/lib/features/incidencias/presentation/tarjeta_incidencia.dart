import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/incidencias/presentation/etiquetas_incidencia.dart';
import 'package:ubbike/features/incidencias/presentation/galeria_fotos_incidencia.dart';
import 'package:ubbike/shared/modelos/incidencia_modelos.dart';
import 'package:ubbike/shared/utilidades/utiles_comun.dart';
import 'package:ubbike/shared/widgets/bloque_mensaje.dart';
import 'package:ubbike/shared/widgets/boton_con_espera.dart';
import 'package:ubbike/shared/widgets/central_widgets.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';

class TarjetaIncidencia extends StatelessWidget {
  const TarjetaIncidencia({
    super.key,
    required this.incidencia,
    required this.mostrarReportante,
    required this.puedeGestionar,
    required this.gestionGuardia,
    required this.mostrarRecordar,
    required this.onActualizarEstado,
    required this.onRecordar,
    required this.onEsperaCumplida,
  });

  final IncidenciaApp incidencia;
  final bool mostrarReportante;
  final bool puedeGestionar;
  final bool gestionGuardia;
  final bool mostrarRecordar;
  final ValueChanged<String> onActualizarEstado;
  final VoidCallback onRecordar;
  final VoidCallback onEsperaCumplida;

  @override
  Widget build(BuildContext context) {
    final cerrada =
        incidencia.estado == 'RESUELTA' || incidencia.estado == 'DESCARTADA';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.report_problem_outlined,
                    color: ColoresUbb.azulApp),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    etiquetaTipoIncidencia(incidencia.tipo),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                ChipEstado(
                  texto: etiquetaEstadoIncidencia(incidencia.estado),
                  color: colorEstadoIncidencia(incidencia.estado),
                ),
              ],
            ),
            const SizedBox(height: 10),
            BloqueMensajeSolicitud(
              titulo: 'Descripción',
              mensaje: incidencia.descripcion,
            ),
            if (incidencia.fotos.isNotEmpty) ...[
              const SizedBox(height: 10),
              GaleriaFotosIncidencia(fotos: incidencia.fotos),
            ],
            const SizedBox(height: 10),
            FilaDato(
              etiqueta: 'Bicicletero',
              valor: incidencia.bicicletero.nombre,
            ),
            FilaDato(
              etiqueta: 'Fecha',
              valor: formatearFecha(incidencia.creadaEn),
            ),
            FilaDato(
              etiqueta: 'Hora',
              valor: formatearHora(incidencia.creadaEn),
            ),
            if (incidencia.bicicleta != null)
              FilaDato(
                etiqueta: 'Bicicleta',
                valor: incidencia.bicicleta!.descripcion,
              ),
            if (mostrarReportante)
              FilaDato(
                etiqueta: 'Reportada por',
                valor: incidencia.reportadaPorUsuario.nombre,
                anchoCompleto: true,
              ),
            if (incidencia.gestionadaPorUsuario != null)
              FilaDato(
                etiqueta: 'Gestionada por',
                valor: incidencia.gestionadaPorUsuario!.nombre,
                anchoCompleto: true,
              ),
            if (incidencia.respuesta != null &&
                incidencia.respuesta!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              BloqueMensajeSolicitud(
                titulo: 'Respuesta de gestión',
                mensaje: incidencia.respuesta!,
              ),
            ],
            if ((puedeGestionar || mostrarRecordar) && !cerrada) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  if (puedeGestionar) ...[
                    OutlinedButton.icon(
                      onPressed: incidencia.estado == 'EN_REVISION'
                          ? null
                          : () => onActualizarEstado('EN_REVISION'),
                      icon: const Icon(Icons.manage_search_outlined),
                      label: const Text('En revisión'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => onActualizarEstado('RESUELTA'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Resolver'),
                    ),
                    if (!gestionGuardia)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ColoresUbb.rojoInstitucional,
                          side: const BorderSide(
                            color: ColoresUbb.rojoInstitucional,
                          ),
                        ),
                        onPressed: () => onActualizarEstado('DESCARTADA'),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Descartar'),
                      ),
                  ],
                  if (mostrarRecordar)
                    BotonConEspera(
                      key: ValueKey('recordar-${incidencia.id}'),
                      segundosRestantes: incidencia.segundosParaRecordar,
                      prefijoEspera: 'Podrás recordar en',
                      etiquetaLista: incidencia.recordatorios > 0
                          ? 'Recordar de nuevo'
                          : 'Recordar',
                      icono: Icons.notifications_active_outlined,
                      onPresionar: onRecordar,
                      alTerminarEspera: onEsperaCumplida,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
