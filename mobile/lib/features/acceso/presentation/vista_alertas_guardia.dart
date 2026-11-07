import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ubbike/features/acceso/application/solicitudes_guardia_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/solicitud_guardia_modelos.dart';
import 'package:ubbike/shared/utilidades/refresco_coalescido.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/lista_con_filtros.dart';
import 'package:ubbike/features/acceso/presentation/solicitud_guardia_widgets.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';

class VistaAlertasGuardia extends ConsumerStatefulWidget {
  const VistaAlertasGuardia({super.key});

  @override
  ConsumerState<VistaAlertasGuardia> createState() =>
      _VistaAlertasGuardiaState();
}

class _VistaAlertasGuardiaState extends ConsumerState<VistaAlertasGuardia> {
  SolicitudesGuardiaVm get vm => ref.read(solicitudesGuardiaVmProvider);
  final controladorBusqueda = TextEditingController();
  String estadoFiltro = 'TODOS';
  late Future<List<SolicitudGuardiaApp>> futuroSolicitudes;
  late final RefrescoCoalescido refrescoAlertas;
  Set<String> solicitudesConocidas = {};
  bool solicitudesInicializadas = false;

  @override
  void initState() {
    super.initState();
    futuroSolicitudes = _cargarSolicitudes();
    refrescoAlertas = RefrescoCoalescido(
      alRefrescar: () async {
        _recargar(avisarNuevas: true);
        await futuroSolicitudes;
      },
    )..iniciarRespaldo();
  }

  @override
  void dispose() {
    refrescoAlertas.detener();
    controladorBusqueda.dispose();
    super.dispose();
  }

  List<SolicitudGuardiaApp> _filtrar(List<SolicitudGuardiaApp> solicitudes) {
    final consulta = controladorBusqueda.text.trim().toLowerCase();
    return solicitudes.where((solicitud) {
      final coincideEstado =
          estadoFiltro == 'TODOS' || solicitud.estado == estadoFiltro;
      final coincideBusqueda = consulta.isEmpty ||
          solicitud.bicicletero.nombre.toLowerCase().contains(consulta) ||
          solicitud.solicitante.nombre.toLowerCase().contains(consulta) ||
          solicitud.solicitante.correo.toLowerCase().contains(consulta);
      return coincideEstado && coincideBusqueda;
    }).toList();
  }

  bool _solicitudAbierta(SolicitudGuardiaApp solicitud) {
    return solicitud.estado != 'RESUELTA' && solicitud.estado != 'CANCELADA';
  }

  Future<List<SolicitudGuardiaApp>> _cargarSolicitudes({
    bool avisarNuevas = false,
  }) async {
    final solicitudes = await vm.listarSolicitudes();
    final abiertas = solicitudes.where(_solicitudAbierta).toList();
    final idsAbiertas = abiertas.map((solicitud) => solicitud.id).toSet();
    final nuevas = abiertas
        .where((solicitud) => !solicitudesConocidas.contains(solicitud.id))
        .toList();
    final debeAvisar =
        avisarNuevas && solicitudesInicializadas && nuevas.isNotEmpty;

    solicitudesConocidas = idsAbiertas;
    solicitudesInicializadas = true;

    if (debeAvisar && mounted) {
      final primera = nuevas.first;
      context.mostrarInfo(
        nuevas.length == 1
            ? 'Nueva alerta en ${primera.bicicletero.nombre}'
            : '${nuevas.length} nuevas alertas asignadas',
      );
    }

    return solicitudes;
  }

  void _recargar({bool avisarNuevas = false}) {
    if (!mounted) {
      return;
    }

    setState(() {
      futuroSolicitudes = _cargarSolicitudes(avisarNuevas: avisarNuevas);
    });
  }

  Widget _tarjetaSolicitud(SolicitudGuardiaApp solicitud) {
    return Padding(
      key: ValueKey(solicitud.id),
      padding: const EdgeInsets.only(bottom: 10),
      child: TarjetaSolicitudGuardia(
        solicitud: solicitud,
        mostrarSolicitante: true,
        onActualizar: (estado, {nota}) async {
          await vm.actualizarEstado(
            solicitudId: solicitud.id,
            estado: estado,
            nota: nota,
          );
          _recargar();
        },
      ),
    );
  }

  List<FiltroActivo> _filtrosActivos() {
    final busqueda = controladorBusqueda.text.trim();
    return [
      if (estadoFiltro != 'TODOS')
        FiltroActivo(
          etiqueta: etiquetaEstadoSolicitud(estadoFiltro),
          onQuitar: () => setState(() => estadoFiltro = 'TODOS'),
        ),
      if (busqueda.isNotEmpty)
        FiltroActivo(
          etiqueta: 'Busca: $busqueda',
          onQuitar: () => setState(controladorBusqueda.clear),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(solicitudesGuardiaVersionProvider, (_, __) {
      refrescoAlertas.solicitar();
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<List<SolicitudGuardiaApp>>(
        future: futuroSolicitudes,
        builder: (context, snapshot) {
          return ListaConFiltros(
            onRefrescar: () async => _recargar(),
            cabecera: [
              const TituloApartado(titulo: 'Alertas'),
              const SizedBox(height: 10),
              TextField(
                controller: controladorBusqueda,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Buscar por bicicletero o solicitante',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: controladorBusqueda.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(controladorBusqueda.clear),
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
                onLimpiar: () => setState(() {
                  estadoFiltro = 'TODOS';
                  controladorBusqueda.clear();
                }),
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
                            onTap: (valor) =>
                                setState(() => estadoFiltro = valor),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            contenido: _contenidoAlertas(snapshot),
          );
        },
      ),
    );
  }

  Widget _contenidoAlertas(AsyncSnapshot<List<SolicitudGuardiaApp>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const SliverCargando();
    }

    if (snapshot.hasError) {
      return SliverToBoxAdapter(
        child: TarjetaAccion(
          icono: Icons.error_outline,
          titulo: 'No se pudieron cargar alertas',
          detalle: 'Revisa tu conexión y toca para reintentar.',
          color: ColoresUbb.rojoInstitucional,
          onTap: _recargar,
        ),
      );
    }

    final todas = snapshot.data ?? [];
    final solicitudes = _filtrar(todas);

    if (solicitudes.isEmpty) {
      return SliverEspacioRestante(
        child: EstadoLista(
          icono: Icons.notifications_active_outlined,
          titulo: todas.isEmpty ? 'Sin alertas' : 'Sin resultados',
          detalle: todas.isEmpty
              ? 'No hay solicitudes asignadas por ahora.'
              : 'Ninguna alerta coincide con tu búsqueda o filtro.',
        ),
      );
    }

    return SliverList.list(
      children: solicitudes.map(_tarjetaSolicitud).toList(),
    );
  }
}
