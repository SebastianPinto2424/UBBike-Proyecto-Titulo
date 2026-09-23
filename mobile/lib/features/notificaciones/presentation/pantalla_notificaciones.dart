import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ubbike/features/notificaciones/application/notificaciones_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/notificacion_app.dart';
import 'package:ubbike/shared/utils/refresco_coalescido.dart';
import 'package:ubbike/shared/widgets/contenedor_responsivo.dart';

class PantallaNotificaciones extends ConsumerStatefulWidget {
  const PantallaNotificaciones({super.key});

  @override
  ConsumerState<PantallaNotificaciones> createState() =>
      _PantallaNotificacionesState();
}

class _PantallaNotificacionesState
    extends ConsumerState<PantallaNotificaciones> {
  NotificacionesVm get vm => ref.read(notificacionesVmProvider);
  List<NotificacionApp> _notificaciones = [];
  String? _cursor;
  bool _cargando = false;
  String? _error;
  late final RefrescoCoalescido refrescoNotificaciones;

  @override
  void initState() {
    super.initState();
    _recargar();
    refrescoNotificaciones = RefrescoCoalescido(alRefrescar: _recargar)
      ..iniciarRespaldo();
  }

  @override
  void dispose() {
    refrescoNotificaciones.detener();
    super.dispose();
  }

  Future<void> _recargar() async {
    if (!mounted || _cargando) {
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final conservar = _notificaciones.length;
      var pagina = await vm.listarPagina();
      final datos = [...pagina.datos];
      while (datos.length < conservar && pagina.cursor != null && mounted) {
        pagina = await vm.listarPagina(cursor: pagina.cursor);
        datos.addAll(pagina.datos);
      }
      if (!mounted) return;
      setState(() {
        _notificaciones =
            {for (final item in datos) item.id: item}.values.toList();
        _cursor = pagina.cursor;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo actualizar. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarMas() async {
    if (_cargando || _cursor == null) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final pagina = await vm.listarPagina(cursor: _cursor);
      if (!mounted) return;
      setState(() {
        final porId = {
          for (final item in [..._notificaciones, ...pagina.datos])
            item.id: item
        };
        _notificaciones = porId.values.toList();
        _cursor = pagina.cursor;
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'No se pudo cargar la página. Intenta nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
      ),
      body: ContenedorResponsivo(
        anchoMaximo: 760,
        child: Builder(
          builder: (context) {
            if (_cargando && _notificaciones.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final notificaciones = _notificaciones;

            if (notificaciones.isEmpty) {
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    _error == null
                        ? Icons.notifications_none_outlined
                        : Icons.cloud_off_outlined,
                    size: 36),
                const SizedBox(height: 12),
                Text(_error ?? 'Sin notificaciones'),
                TextButton(
                    onPressed: _recargar, child: const Text('Actualizar')),
              ]));
            }

            final ordenadas = [...notificaciones]..sort((a, b) {
                if (a.leida != b.leida) return a.leida ? 1 : -1;
                return b.creadaEn.compareTo(a.creadaEn);
              });

            return RefreshIndicator(
              onRefresh: _recargar,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: ordenadas.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == ordenadas.length) {
                    return Column(children: [
                      if (_error != null) Text(_error!),
                      if (_cursor != null)
                        OutlinedButton(
                            onPressed: _cargando ? null : _cargarMas,
                            child: Text(_cargando
                                ? 'Cargando…'
                                : 'Cargar más notificaciones')),
                    ]);
                  }
                  return _TarjetaNotificacion(
                    notificacion: ordenadas[index],
                    onTap: () => _abrirNotificacion(ordenadas[index]),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _abrirNotificacion(NotificacionApp notificacion) async {
    try {
      if (!notificacion.leida) {
        await vm.marcarLeida(notificacion.id);
      }
    } catch (_) {}

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(notificacion);
  }
}

class _TarjetaNotificacion extends StatelessWidget {
  const _TarjetaNotificacion({
    required this.notificacion,
    required this.onTap,
  });

  final NotificacionApp notificacion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorPorTipo(notificacion.tipo);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: notificacion.leida
                  ? ColoresUbb.borde
                  : color.withValues(alpha: 0.34),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _iconoPorTipo(notificacion.tipo),
                      color: color,
                      size: 22,
                    ),
                  ),
                  if (!notificacion.leida)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notificacion.tituloVisible,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: ColoresUbb.textoPrincipal,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notificacion.mensajeVisible,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ColoresUbb.textoPrincipal,
                            height: 1.25,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _tiempoRelativo(notificacion.creadaEn),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ColoresUbb.textoSecundario,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: ColoresUbb.textoSecundario.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconoPorTipo(String tipo) {
    switch (tipo) {
      case 'CUENTA':
        return Icons.manage_accounts_outlined;
      case 'SOLICITUD_GUARDIA':
        return Icons.headset_mic_outlined;
      case 'SEGURIDAD':
        return Icons.security_outlined;
      case 'MOVIMIENTO':
        return Icons.swap_horiz_outlined;
      case 'INCIDENCIA':
        return Icons.flag_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorPorTipo(String tipo) {
    switch (tipo) {
      case 'CUENTA':
        return ColoresUbb.azulApp;
      case 'SOLICITUD_GUARDIA':
        return ColoresUbb.turquesa;
      case 'SEGURIDAD':
        return ColoresUbb.rojoInstitucional;
      case 'MOVIMIENTO':
        return ColoresUbb.exito;
      case 'INCIDENCIA':
        return ColoresUbb.amarilloInstitucional;
      default:
        return ColoresUbb.azulApp;
    }
  }

  String _tiempoRelativo(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 1) {
      return 'Hace un momento';
    }
    if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    }
    if (diferencia.inHours < 24) {
      final h = diferencia.inHours;
      return 'Hace $h ${h == 1 ? 'hora' : 'horas'}';
    }
    if (diferencia.inDays < 7) {
      final d = diferencia.inDays;
      return 'Hace $d ${d == 1 ? 'día' : 'días'}';
    }
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }
}
