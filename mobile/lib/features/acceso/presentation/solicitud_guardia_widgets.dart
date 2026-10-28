import 'package:flutter/material.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/solicitud_guardia_modelos.dart';
import 'package:ubbike/shared/utilidades/utiles_comun.dart';
import 'package:ubbike/shared/widgets/bloque_mensaje.dart';
import 'package:ubbike/shared/widgets/boton_con_espera.dart';
import 'package:ubbike/shared/widgets/botones_accion.dart';
import 'package:ubbike/shared/widgets/central_widgets.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';

class TarjetaSolicitudGuardia extends StatelessWidget {
  const TarjetaSolicitudGuardia({
    super.key,
    required this.solicitud,
    this.mostrarSolicitante = false,
    this.permitirNotificarCentral = false,
    this.permitirNotificarUsuario = false,
    this.mostrarAccionesGuardia = true,
    this.onCerrarSinResolver,
    this.onEsperaCumplida,
    this.onActualizar,
    this.onNotificarGuardia,
    this.onCancelarSolicitante,
  });

  final SolicitudGuardiaApp solicitud;
  final bool mostrarSolicitante;
  final bool permitirNotificarCentral;
  final bool permitirNotificarUsuario;
  final bool mostrarAccionesGuardia;

  final VoidCallback? onEsperaCumplida;
  final Future<void> Function(String estado, {String? nota})? onActualizar;
  final Future<void> Function()? onNotificarGuardia;
  final VoidCallback? onCancelarSolicitante;
  final VoidCallback? onCerrarSinResolver;

  @override
  Widget build(BuildContext context) {
    final cerrada =
        solicitud.estado == 'RESUELTA' || solicitud.estado == 'CANCELADA';
    final mensaje = solicitud.mensaje?.trim();
    final puedeRecordar = onActualizar == null &&
        permitirNotificarUsuario &&
        onNotificarGuardia != null;
    final etiquetaMensaje =
        mostrarSolicitante ? 'Mensaje del solicitante' : 'Mensaje enviado';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.support_agent, color: ColoresUbb.azulApp),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    solicitud.bicicletero.nombre,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                ChipEstado(
                  texto: etiquetaEstadoSolicitud(solicitud.estado),
                  color: _colorEstadoSolicitud(solicitud.estado),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _etiquetaTipoSolicitud(solicitud.tipo),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              solicitud.bicicletero.ubicacion,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ColoresUbb.textoSecundario,
                  ),
            ),
            const SizedBox(height: 8),
            FilaDato(
              etiqueta: 'Fecha solicitud',
              valor: formatearFecha(solicitud.creadaEn),
            ),
            FilaDato(
              etiqueta: 'Hora solicitud',
              valor: formatearHora(solicitud.creadaEn),
            ),
            if (mostrarSolicitante) ...[
              const SizedBox(height: 8),
              FilaDato(
                etiqueta: 'Solicitante',
                valor: solicitud.solicitante.nombre,
              ),
              FilaDato(
                etiqueta: 'Correo solicitante',
                valor: solicitud.solicitante.correo,
                anchoCompleto: true,
              ),
            ],
            if (solicitud.guardiaAsignado != null) ...[
              const SizedBox(height: 8),
              FilaDato(
                etiqueta: 'Guardia asignado',
                valor: solicitud.guardiaAsignado!.nombre,
              ),
            ],
            if (solicitud.notificadaGuardiaEn != null) ...[
              const SizedBox(height: 8),
              FilaDato(
                etiqueta: 'Guardia notificado',
                valor: _formatearFechaHoraSolicitud(
                  solicitud.notificadaGuardiaEn!,
                ),
              ),
            ],
            if (solicitud.notificacionesGuardia > 0) ...[
              const SizedBox(height: 8),
              FilaDato(
                etiqueta: 'Avisos enviados',
                valor:
                    '${solicitud.notificacionesGuardia} ${solicitud.notificacionesGuardia == 1 ? 'vez' : 'veces'}',
              ),
            ],
            if (solicitud.ultimaNotificacionUsuarioEn != null) ...[
              const SizedBox(height: 8),
              FilaDato(
                etiqueta: 'Último recordatorio',
                valor: _formatearFechaHoraSolicitud(
                  solicitud.ultimaNotificacionUsuarioEn!,
                ),
              ),
            ],
            if (solicitud.respondidaPorGuardiaEn != null) ...[
              const SizedBox(height: 8),
              FilaDato(
                etiqueta: 'Respuesta del guardia',
                valor: _formatearFechaHoraSolicitud(
                  solicitud.respondidaPorGuardiaEn!,
                ),
              ),
            ],
            if (solicitud.enCaminoEn != null) ...[
              const SizedBox(height: 8),
              FilaDato(
                etiqueta: 'Guardia en camino desde',
                valor: _formatearFechaHoraSolicitud(solicitud.enCaminoEn!),
              ),
            ],
            if (solicitud.resueltaEn != null) ...[
              const SizedBox(height: 8),
              FilaDato(
                etiqueta: _etiquetaCierre(solicitud),
                valor: _formatearFechaHoraSolicitud(solicitud.resueltaEn!),
              ),
            ],
            if (solicitud.guardiaAsignado == null &&
                solicitud.guardiasAsignados.isNotEmpty) ...[
              const SizedBox(height: 8),
              FilaDato(
                etiqueta: 'Guardias notificados',
                valor: solicitud.guardiasAsignados
                    .map((guardia) => guardia.nombre)
                    .join(', '),
                anchoCompleto: true,
              ),
            ],
            if (mensaje != null && mensaje.isNotEmpty) ...[
              const SizedBox(height: 12),
              BloqueMensajeSolicitud(
                titulo: etiquetaMensaje,
                mensaje: mensaje,
              ),
            ],
            if (solicitud.motivoCierre != null &&
                solicitud.motivoCierre!.isNotEmpty) ...[
              const SizedBox(height: 12),
              BloqueMensajeSolicitud(
                titulo: solicitud.cerradaPor == 'SOLICITANTE'
                    ? 'Motivo del solicitante'
                    : 'Motivo de cierre (Central)',
                mensaje: solicitud.motivoCierre!,
              ),
            ],
            if (!cerrada && onActualizar != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (permitirNotificarUsuario && onNotificarGuardia != null)
                    _BotonRecordarSolicitud(
                      solicitud: solicitud,
                      prefijoEspera: 'Podrás recordar en',
                      onPresionar: () => _notificarGuardia(context),
                      alTerminarEspera: onEsperaCumplida,
                    ),
                  if (permitirNotificarCentral &&
                      solicitud.guardiaAsignado != null)
                    _BotonRecordarSolicitud(
                      solicitud: solicitud,
                      prefijoEspera: 'Reenviar en',
                      onPresionar: () => _actualizar(context, 'NOTIFICADA'),
                      alTerminarEspera: onEsperaCumplida,
                    ),
                  if (mostrarAccionesGuardia) ...[
                    OutlinedButton.icon(
                      onPressed: solicitud.estado == 'EN_CAMINO'
                          ? null
                          : () => _actualizar(context, 'EN_CAMINO'),
                      icon: const Icon(Icons.directions_walk),
                      label: const Text('Voy en camino'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _actualizar(context, 'RESUELTA'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Marcar resuelta'),
                    ),
                  ],
                  if (onCerrarSinResolver != null) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColoresUbb.rojoInstitucional,
                        side: const BorderSide(
                          color: ColoresUbb.rojoInstitucional,
                        ),
                      ),
                      onPressed: onCerrarSinResolver,
                      icon: const Icon(Icons.block_outlined),
                      label: const Text('Cerrar sin resolver'),
                    ),
                  ],
                ],
              ),
            ],
            if (!cerrada &&
                (puedeRecordar || onCancelarSolicitante != null)) ...[
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (puedeRecordar && solicitud.guardiaAsignado == null)
                    const _IndicadorCentralAvisada(),
                  if (puedeRecordar && solicitud.guardiaAsignado != null)
                    _BotonRecordarSolicitud(
                      solicitud: solicitud,
                      prefijoEspera: 'Podrás recordar en',
                      onPresionar: () => _notificarGuardia(context),
                      alTerminarEspera: onEsperaCumplida,
                    ),
                  if (puedeRecordar && onCancelarSolicitante != null)
                    const SizedBox(height: 10),
                  if (onCancelarSolicitante != null)
                    BotonAccion(
                      accion: AccionBoton(
                        texto: 'Cancelar solicitud',
                        color: ColoresUbb.rojoInstitucional,
                        icono: Icons.block,
                        onPressed: onCancelarSolicitante,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _actualizar(
    BuildContext context,
    String estado, {
    String? nota,
  }) async {
    try {
      await onActualizar?.call(estado, nota: nota);
      if (context.mounted) {
        context.mostrarExito('Solicitud ${etiquetaEstadoSolicitud(estado)}');
      }
    } on ExcepcionApi catch (error) {
      if (context.mounted) {
        context.mostrarError(error.mensaje);
      }
    }
  }

  Future<void> _notificarGuardia(BuildContext context) async {
    try {
      await onNotificarGuardia?.call();
    } on ExcepcionApi catch (error) {
      if (context.mounted) {
        context.mostrarError(error.mensaje);
      }
    }
  }
}

class _IndicadorCentralAvisada extends StatelessWidget {
  const _IndicadorCentralAvisada();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ColoresUbb.exito.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresUbb.exito.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 20,
            color: ColoresUbb.exito,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Central avisada',
                  style: textTheme.bodyMedium?.copyWith(
                    color: ColoresUbb.exito,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nadie gestiona este bicicletero por ahora. Tu solicitud llegará al guardia en cuanto tome el turno.',
                  style: textTheme.bodySmall?.copyWith(
                    color: ColoresUbb.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _etiquetaTipoSolicitud(String tipo) {
  return switch (tipo) {
    'GUARDIA_AUSENTE' => 'Guardia ausente',
    'REQUIERE_SERVICIO' => 'Requiere servicio',
    _ => tipo,
  };
}

class _BotonRecordarSolicitud extends StatelessWidget {
  const _BotonRecordarSolicitud({
    required this.solicitud,
    required this.prefijoEspera,
    required this.onPresionar,
    this.alTerminarEspera,
  });

  final SolicitudGuardiaApp solicitud;
  final String prefijoEspera;
  final VoidCallback onPresionar;
  final VoidCallback? alTerminarEspera;

  bool get _esReenvio => prefijoEspera.startsWith('Reenviar');

  @override
  Widget build(BuildContext context) {
    if (solicitud.respondidaPorGuardiaEn != null ||
        solicitud.estado == 'EN_CAMINO') {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.notifications_active_outlined),
        label: Text(solicitud.estado == 'EN_CAMINO'
            ? 'Guardia en camino'
            : 'Guardia respondió'),
      );
    }

    final yaAviso = solicitud.notificacionesGuardia > 0;

    return BotonConEspera(
      key: ValueKey('$prefijoEspera-${solicitud.id}'),
      segundosRestantes: solicitud.segundosParaNotificarGuardia,
      prefijoEspera: prefijoEspera,
      etiquetaLista: _esReenvio
          ? (yaAviso ? 'Reenviar aviso' : 'Avisar guardia')
          : (yaAviso ? 'Recordar al guardia' : 'Avisar al guardia'),
      icono: Icons.notifications_active_outlined,
      onPresionar: onPresionar,
      alTerminarEspera: alTerminarEspera,
    );
  }
}

String etiquetaEstadoSolicitud(String estado) {
  return switch (estado) {
    'PENDIENTE' => 'Pendiente',
    'NOTIFICADA' => 'Guardia notificado',
    'EN_CAMINO' => 'Guardia en camino',
    'RESUELTA' => 'Resuelta',
    'CANCELADA' => 'Cancelada',
    _ => estado,
  };
}

Color _colorEstadoSolicitud(String estado) {
  return switch (estado) {
    'PENDIENTE' => ColoresUbb.rojoInstitucional,
    'NOTIFICADA' => ColoresUbb.azulApp,
    'EN_CAMINO' => ColoresUbb.turquesa,
    'RESUELTA' => ColoresUbb.exito,
    'CANCELADA' => ColoresUbb.textoSecundario,
    _ => ColoresUbb.azulApp,
  };
}

String _formatearFechaHoraSolicitud(DateTime fecha) {
  return '${formatearFecha(fecha)} ${formatearHora(fecha)}';
}

String _etiquetaCierre(SolicitudGuardiaApp solicitud) {
  if (solicitud.estado == 'RESUELTA') {
    return 'Resuelta';
  }
  return switch (solicitud.cerradaPor) {
    'SOLICITANTE' => 'Cancelada por el solicitante',
    'CENTRAL' => 'Cerrada por central',
    _ => 'Cancelada',
  };
}
