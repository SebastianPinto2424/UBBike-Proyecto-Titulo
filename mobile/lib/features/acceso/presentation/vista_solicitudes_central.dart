import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ubbike/features/acceso/application/solicitudes_guardia_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/acceso/data/solicitud_guardia_modelos.dart';
import 'package:ubbike/shared/utils/auto_refresco.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/features/acceso/presentation/solicitud_guardia_widgets.dart';
import 'package:ubbike/features/historial/presentation/widgets_movimientos.dart';

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

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(solicitudesGuardiaVersionProvider, (_, __) {
      solicitarRefresco();
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _recargar(),
              child: FutureBuilder<List<SolicitudGuardiaApp>>(
                future: futuroSolicitudes,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    _ultimoDato = snapshot.data;
                  }
                  final cargandoInicial =
                      snapshot.connectionState == ConnectionState.waiting &&
                          _ultimoDato == null;
                  if (cargandoInicial) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(
                          height: 180,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    );
                  }

                  if (snapshot.hasError && _ultimoDato == null) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        TarjetaAccion(
                          icono: Icons.error_outline,
                          titulo: 'No se pudieron cargar solicitudes',
                          detalle: 'Revisa tu conexión y toca para reintentar.',
                          color: ColoresUbb.rojoInstitucional,
                          onTap: _recargar,
                        ),
                      ],
                    );
                  }

                  final solicitudes =
                      _ultimoDato ?? const <SolicitudGuardiaApp>[];

                  if (solicitudes.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        EstadoLista(
                          icono: Icons.campaign_outlined,
                          titulo: busquedaController.text.trim().isEmpty &&
                                  estadoFiltro == 'TODOS'
                              ? 'Sin solicitudes'
                              : 'Sin resultados',
                          detalle: busquedaController.text.trim().isEmpty &&
                                  estadoFiltro == 'TODOS'
                              ? 'No hay solicitudes de guardia registradas.'
                              : 'Ninguna solicitud coincide con la búsqueda o filtro.',
                        ),
                      ],
                    );
                  }

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: solicitudes
                        .map(
                          (solicitud) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TarjetaSolicitudGuardia(
                              solicitud: solicitud,
                              mostrarSolicitante: true,
                              permitirNotificarCentral: true,
                              mostrarAccionesGuardia: false,
                              permitirCierreCentral: true,
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
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
