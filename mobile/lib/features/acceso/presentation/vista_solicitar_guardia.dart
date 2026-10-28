import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ubbike/features/acceso/application/solicitudes_guardia_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/solicitud_guardia_modelos.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/utilidades/auto_refresco.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/features/acceso/presentation/hoja_cancelar_solicitud.dart';
import 'package:ubbike/features/acceso/presentation/hoja_solicitar_atencion.dart';
import 'package:ubbike/features/acceso/presentation/solicitud_guardia_widgets.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';

class VistaSolicitarGuardia extends ConsumerStatefulWidget {
  const VistaSolicitarGuardia({super.key});

  @override
  ConsumerState<VistaSolicitarGuardia> createState() =>
      _VistaSolicitarGuardiaState();
}

class _VistaSolicitarGuardiaState extends ConsumerState<VistaSolicitarGuardia>
    with AutoRefrescoMixin {
  SolicitudesGuardiaVm get vm => ref.read(solicitudesGuardiaVmProvider);
  List<BicicleteroApp> bicicleteros = [];
  late Future<List<SolicitudGuardiaApp>> futuroSolicitudes;
  List<SolicitudGuardiaApp>? ultimasSolicitudes;
  ValueNotifier<SolicitudGuardiaApp>? solicitudEnCancelacion;
  bool ultimaRecargaFallida = false;
  bool abriendoFormulario = false;
  bool notificando = false;
  Timer? temporizadorCooldown;

  @override
  void initState() {
    super.initState();
    futuroSolicitudes = _cargarSolicitudes();
    _cargarBicicleteros();
    iniciarAutoRefresco();
  }

  @override
  void dispose() {
    temporizadorCooldown?.cancel();
    super.dispose();
  }

  @override
  bool get datosDesactualizados => ultimaRecargaFallida;

  @override
  Future<void> refrescar() async {
    _recargar();
    await futuroSolicitudes.then<void>((_) {}, onError: (_) {});
  }

  Future<List<SolicitudGuardiaApp>> _cargarSolicitudes() async {
    try {
      final solicitudes = await vm.listarSolicitudes();
      ultimasSolicitudes = solicitudes;
      ultimaRecargaFallida = false;
      _actualizarSolicitudEnCancelacion(solicitudes);
      _programarRefrescoCooldown(solicitudes);
      return solicitudes;
    } catch (_) {
      ultimaRecargaFallida = true;
      final anteriores = ultimasSolicitudes;
      if (anteriores == null) rethrow;
      return anteriores;
    }
  }

  void _actualizarSolicitudEnCancelacion(
    List<SolicitudGuardiaApp> solicitudes,
  ) {
    final enCancelacion = solicitudEnCancelacion;
    if (enCancelacion == null) {
      return;
    }
    final actual = solicitudes
        .where((solicitud) => solicitud.id == enCancelacion.value.id)
        .firstOrNull;
    if (actual != null) enCancelacion.value = actual;
  }

  void _programarRefrescoCooldown(List<SolicitudGuardiaApp> solicitudes) {
    temporizadorCooldown?.cancel();

    final pendientes = solicitudes
        .map((solicitud) => solicitud.segundosParaNotificarGuardia ?? 0)
        .where((segundos) => segundos > 0);

    if (pendientes.isEmpty || !mounted) {
      return;
    }

    final segundosMinimos = pendientes.reduce((a, b) => a < b ? a : b);
    temporizadorCooldown = Timer(
      Duration(seconds: segundosMinimos + 1),
      _recargar,
    );
  }

  Future<void> _cargarBicicleteros() async {
    try {
      final datos = await vm.listarBicicleteros();
      if (mounted) {
        setState(() => bicicleteros = datos);
      }
    } catch (_) {}
  }

  void _recargar() {
    if (!mounted) {
      return;
    }
    setState(() {
      futuroSolicitudes = _cargarSolicitudes();
    });
  }

  Future<String?> _crearSolicitud(String bicicleteroId, String mensaje) async {
    try {
      final solicitud = await vm.crearSolicitud(
        bicicleteroId: bicicleteroId,
        tipo: 'REQUIERE_SERVICIO',
        mensaje: mensaje,
      );

      if (mounted) {
        _recargar();
        context.mostrarExito(
          solicitud.guardiaAsignado == null
              ? 'Por ahora nadie gestiona este bicicletero. Avisamos a central y tu solicitud llegará al guardia en cuanto tome el turno.'
              : 'Solicitud enviada al guardia con copia a central',
        );
      }
      return null;
    } on ExcepcionApi catch (error) {
      return error.mensaje;
    } catch (_) {
      return mensajeSinConexion;
    }
  }

  Future<void> _abrirFormulario() async {
    if (abriendoFormulario) {
      return;
    }
    if (bicicleteros.isEmpty) {
      setState(() => abriendoFormulario = true);
      try {
        final datos = await vm.listarBicicleteros();
        if (mounted) {
          setState(() => bicicleteros = datos);
        }
      } on ExcepcionApi catch (error) {
        if (mounted) {
          context.mostrarError(error.mensaje);
        }
        return;
      } catch (_) {
        if (mounted) {
          context.mostrarError(mensajeSinConexion);
        }
        return;
      } finally {
        if (mounted) {
          setState(() => abriendoFormulario = false);
        }
      }
    }
    if (!mounted) {
      return;
    }
    if (bicicleteros.isEmpty) {
      context.mostrarError('No hay bicicleteros disponibles por ahora.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => HojaSolicitarAtencion(
        bicicleteros: bicicleteros,
        onEnviar: _crearSolicitud,
      ),
    );
  }

  Future<void> _abrirCancelacion(SolicitudGuardiaApp solicitud) async {
    final enVivo = ValueNotifier(solicitud);
    solicitudEnCancelacion = enVivo;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => HojaCancelarSolicitud(
        solicitud: enVivo,
        onCancelar: (motivo) => _cancelarSolicitud(solicitud, motivo),
      ),
    );
    if (identical(solicitudEnCancelacion, enVivo)) {
      solicitudEnCancelacion = null;
    }
    enVivo.dispose();
  }

  Future<String?> _cancelarSolicitud(
    SolicitudGuardiaApp solicitud,
    String motivo,
  ) async {
    try {
      await vm.cancelarSolicitud(solicitudId: solicitud.id, motivo: motivo);
      if (mounted) {
        _recargar();
        context.mostrarExito('Solicitud cancelada');
      }
      return null;
    } on ExcepcionApi catch (error) {
      return error.mensaje;
    } catch (_) {
      return mensajeSinConexion;
    }
  }

  Future<void> _notificarGuardia(SolicitudGuardiaApp solicitud) async {
    if (notificando) {
      return;
    }

    setState(() => notificando = true);

    try {
      await vm.notificarGuardia(
        solicitudId: solicitud.id,
      );

      if (mounted) {
        _recargar();
        context.mostrarInfo('Guardia notificado nuevamente');
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } finally {
      if (mounted) {
        setState(() => notificando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
        solicitudesGuardiaVersionProvider, (_, __) => solicitarRefresco());
    ref.listen<int>(
        bicicleterosVersionProvider, (_, __) => _cargarBicicleteros());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EncabezadoAtencionGuardia(
            abriendo: abriendoFormulario,
            onSolicitar: _abrirFormulario,
          ),
          const SizedBox(height: 16),
          const TituloApartado(titulo: 'Solicitudes recientes'),
          const SizedBox(height: 10),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _recargar(),
              child: FutureBuilder<List<SolicitudGuardiaApp>>(
                future: futuroSolicitudes,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: const [
                        SizedBox(
                          height: 180,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    );
                  }

                  if (snapshot.hasError) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        TarjetaAccion(
                          icono: Icons.error_outline,
                          titulo: 'No se pudieron cargar tus solicitudes',
                          detalle: 'Revisa tu conexión y toca para reintentar.',
                          color: ColoresUbb.rojoInstitucional,
                          onTap: _recargar,
                        ),
                      ],
                    );
                  }

                  final solicitudes = snapshot.data ?? [];

                  if (solicitudes.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: const [
                        EstadoLista(
                          icono: Icons.support_agent,
                          titulo: 'Sin solicitudes recientes',
                          detalle:
                              'Cuando solicites atención, el estado aparecerá aquí.',
                        ),
                      ],
                    );
                  }

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      ...solicitudes.map(
                        (solicitud) => Padding(
                          key: ValueKey(solicitud.id),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TarjetaSolicitudGuardia(
                            solicitud: solicitud,
                            mostrarAccionesGuardia: false,
                            permitirNotificarUsuario: true,
                            onNotificarGuardia: () =>
                                _notificarGuardia(solicitud),
                            onCancelarSolicitante: () =>
                                _abrirCancelacion(solicitud),
                            onEsperaCumplida: _recargar,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EncabezadoAtencionGuardia extends StatelessWidget {
  const _EncabezadoAtencionGuardia({
    required this.abriendo,
    required this.onSolicitar,
  });

  final bool abriendo;
  final VoidCallback onSolicitar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Atención del guardia',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Solicita apoyo si el guardia no está disponible en el bicicletero.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColoresUbb.textoSecundario,
              ),
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                backgroundColor: ColoresUbb.azulApp,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: abriendo ? null : onSolicitar,
              icon: abriendo
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add, size: 18),
              label: const Text(
                'Solicitar atención',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
