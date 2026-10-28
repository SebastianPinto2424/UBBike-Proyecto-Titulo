import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ubbike/features/acceso/application/solicitudes_guardia_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/acceso/presentation/dialogo_nota_cierre.dart';
import 'package:ubbike/shared/modelos/solicitud_guardia_modelos.dart';
import 'package:ubbike/shared/utilidades/auto_refresco.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/lista_con_filtros.dart';
import 'package:ubbike/features/acceso/presentation/solicitud_guardia_widgets.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';

class VistaSolicitudesCentral extends ConsumerStatefulWidget {
  const VistaSolicitudesCentral({super.key});

  @override
  ConsumerState<VistaSolicitudesCentral> createState() =>
      _VistaSolicitudesCentralState();
}

class _VistaSolicitudesCentralState
    extends ConsumerState<VistaSolicitudesCentral> with AutoRefrescoMixin {
  SolicitudesGuardiaVm get vm => ref.read(solicitudesGuardiaVmProvider);
  final busquedaController = TextEditingController();
  Timer? temporizadorBusqueda;
  String estadoFiltro = 'TODOS';
  late Future<List<SolicitudGuardiaApp>> futuroSolicitudes;
  List<SolicitudGuardiaApp>? _ultimoDato;

  @override
  void initState() {
    super.initState();
    futuroSolicitudes = _cargarSolicitudes();
    iniciarAutoRefresco();
  }

  @override
  Future<void> refrescar() async {
    if (mounted) {
      setState(() {
        futuroSolicitudes = _cargarSolicitudes();
      });
    }
  }

  @override
  void dispose() {
    temporizadorBusqueda?.cancel();
    busquedaController.dispose();
    super.dispose();
  }

  Future<List<SolicitudGuardiaApp>> _cargarSolicitudes() {
    return vm.listarSolicitudes(
      estado: estadoFiltro,
      q: busquedaController.text,
      limite: 300,
    );
  }

  void _recargar() {
    temporizadorBusqueda?.cancel();
    setState(() {
      futuroSolicitudes = _cargarSolicitudes();
    });
  }

  void _programarBusqueda() {
    setState(() {});
    temporizadorBusqueda?.cancel();
    temporizadorBusqueda = Timer(
      const Duration(milliseconds: 350),
      _recargar,
    );
  }

  void _limpiarFiltros() {
    temporizadorBusqueda?.cancel();
    busquedaController.clear();
    setState(() {
      estadoFiltro = 'TODOS';
      futuroSolicitudes = _cargarSolicitudes();
    });
  }

  Future<void> _cerrarSinResolver(SolicitudGuardiaApp solicitud) async {
    final nota = await showDialog<String>(
      context: context,
      builder: (_) => const DialogoNotaCierre(),
    );
    if (nota == null || !mounted) {
      return;
    }

    try {
      await vm.actualizarEstado(
        solicitudId: solicitud.id,
        estado: 'CANCELADA',
        nota: nota,
      );
      if (mounted) {
        _recargar();
        context.mostrarExito('Solicitud cerrada sin resolver');
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError(mensajeSinConexion);
      }
    }
  }

  List<FiltroActivo> _filtrosActivos() {
    final busqueda = busquedaController.text.trim();
    return [
      if (estadoFiltro != 'TODOS')
        FiltroActivo(
          etiqueta: etiquetaEstadoSolicitud(estadoFiltro),
          onQuitar: () {
            setState(() {
              estadoFiltro = 'TODOS';
              futuroSolicitudes = _cargarSolicitudes();
            });
          },
        ),
      if (busqueda.isNotEmpty)
        FiltroActivo(
          etiqueta: 'Busca: $busqueda',
          onQuitar: () {
            temporizadorBusqueda?.cancel();
            busquedaController.clear();
            _recargar();
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(solicitudesGuardiaVersionProvider, (_, __) {
      solicitarRefresco();
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<List<SolicitudGuardiaApp>>(
        future: futuroSolicitudes,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _ultimoDato = snapshot.data;
          }

          return ListaConFiltros(
            onRefrescar: () async => _recargar(),
            cabecera: [
              const TituloApartado(titulo: 'Solicitudes'),
              const SizedBox(height: 10),
              TextField(
                controller: busquedaController,
                textInputAction: TextInputAction.search,
                onChanged: (_) => _programarBusqueda(),
                onSubmitted: (_) => _recargar(),
                decoration: InputDecoration(
                  labelText: 'Buscar por bicicletero, solicitante o guardia',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: busquedaController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            temporizadorBusqueda?.cancel();
                            busquedaController.clear();
                            _recargar();
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              PanelFiltros(
                titulo: 'Filtros',
                activos: _filtrosActivos(),
                detalle: estadoFiltro == 'TODOS'
                    ? 'Todas'
                    : etiquetaEstadoSolicitud(estadoFiltro),
                onLimpiar: _limpiarFiltros,
                children: [
                  EtiquetaFiltro(
                    texto: 'Estado',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in [
                          'TODOS',
                          'PENDIENTE',
                          'NOTIFICADA',
                          'EN_CAMINO',
                          'RESUELTA',
                          'CANCELADA',
                        ])
                          FiltroChip(
                            label: item == 'TODOS'
                                ? 'Todas'
                                : etiquetaEstadoSolicitud(item),
                            value: item,
                            selectedValue: estadoFiltro,
                            onTap: (valor) {
                              setState(() {
                                estadoFiltro = valor;
                                futuroSolicitudes = _cargarSolicitudes();
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            contenido: _contenidoSolicitudes(snapshot),
          );
        },
      ),
    );
  }

  Widget _contenidoSolicitudes(
      AsyncSnapshot<List<SolicitudGuardiaApp>> snapshot) {
    final cargandoInicial =
        snapshot.connectionState == ConnectionState.waiting &&
            _ultimoDato == null;
    if (cargandoInicial) {
      return const SliverCargando();
    }

    if (snapshot.hasError && _ultimoDato == null) {
      return SliverToBoxAdapter(
        child: TarjetaAccion(
          icono: Icons.error_outline,
          titulo: 'No se pudieron cargar solicitudes',
          detalle: 'Revisa tu conexión y toca para reintentar.',
          color: ColoresUbb.rojoInstitucional,
          onTap: _recargar,
        ),
      );
    }

    final solicitudes = _ultimoDato ?? const <SolicitudGuardiaApp>[];

    if (solicitudes.isEmpty) {
      final sinFiltros =
          busquedaController.text.trim().isEmpty && estadoFiltro == 'TODOS';
      return SliverEspacioRestante(
        child: EstadoLista(
          icono: Icons.campaign_outlined,
          titulo: sinFiltros ? 'Sin solicitudes' : 'Sin resultados',
          detalle: sinFiltros
              ? 'No hay solicitudes de guardia registradas.'
              : 'Ninguna solicitud coincide con la búsqueda o filtro.',
        ),
      );
    }

    return SliverList.list(
      children: solicitudes
          .map(
            (solicitud) => Padding(
              key: ValueKey(solicitud.id),
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaSolicitudGuardia(
                solicitud: solicitud,
                mostrarSolicitante: true,
                permitirNotificarCentral: true,
                mostrarAccionesGuardia: false,
                onCerrarSinResolver: () => _cerrarSinResolver(solicitud),
                onEsperaCumplida: _recargar,
                onActualizar: (estado, {nota}) async {
                  await vm.actualizarEstado(
                    solicitudId: solicitud.id,
                    estado: estado,
                    nota: nota,
                  );
                  _recargar();
                },
              ),
            ),
          )
          .toList(),
    );
  }
}
