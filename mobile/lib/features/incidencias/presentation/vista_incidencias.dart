import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/incidencias/application/incidencias_vm.dart';
import 'package:ubbike/features/incidencias/data/borrador_incidencia.dart';
import 'package:ubbike/features/incidencias/presentation/dialogo_respuesta_incidencia.dart';
import 'package:ubbike/features/incidencias/presentation/etiquetas_incidencia.dart';
import 'package:ubbike/features/incidencias/presentation/filtros_incidencias.dart';
import 'package:ubbike/features/incidencias/presentation/hoja_registrar_incidencia.dart';
import 'package:ubbike/features/incidencias/presentation/tarjeta_incidencia.dart';
import 'package:ubbike/shared/modelos/incidencia_modelos.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/lista_con_filtros.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';

class VistaIncidencias extends ConsumerStatefulWidget {
  const VistaIncidencias({
    super.key,
    required this.mostrarReportante,
    required this.puedeGestionar,
    this.permitirBicicletaPropia = false,
    this.gestionGuardia = false,
    this.gestionCentral = false,
    this.soloPropias = false,
  });

  final bool mostrarReportante;
  final bool puedeGestionar;
  final bool permitirBicicletaPropia;
  final bool gestionGuardia;
  final bool gestionCentral;
  final bool soloPropias;

  @override
  ConsumerState<VistaIncidencias> createState() => _VistaIncidenciasState();
}

class _VistaIncidenciasState extends ConsumerState<VistaIncidencias> {
  final controladorBusqueda = TextEditingController();

  AutoDisposeAsyncNotifierProvider<IncidenciasVm, List<IncidenciaApp>>
      get _vmProvider => widget.soloPropias
          ? incidenciasPropiasVmProvider
          : incidenciasVmProvider;
  AutoDisposeStateProvider<FiltrosIncidencias> get _filtrosProvider =>
      widget.soloPropias
          ? filtrosIncidenciasPropiasProvider
          : filtrosIncidenciasProvider;
  IncidenciasVm get vm => ref.read(_vmProvider.notifier);

  ({bool gestionGuardia, bool permitirBicicletaPropia}) get _argsFormulario => (
        gestionGuardia: widget.gestionGuardia,
        permitirBicicletaPropia: widget.permitirBicicletaPropia,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_retomarBorrador());
    });
  }

  @override
  void dispose() {
    controladorBusqueda.dispose();
    super.dispose();
  }

  Future<void> _retomarBorrador() async {
    if (!await existeBorradorIncidencia() || !mounted) {
      return;
    }
    try {
      await ref.read(datosFormularioIncidenciaProvider(_argsFormulario).future);
    } catch (_) {
      return;
    }
    final borrador = await tomarBorradorIncidencia();
    if (borrador != null && mounted) {
      await _abrirFormulario(borrador: borrador);
    }
  }

  void _recargar() {
    vm.recargar();
  }

  void _programarBusqueda() {
    setState(() {});
    vm.buscar(controladorBusqueda.text);
  }

  void _limpiarFiltros() {
    controladorBusqueda.clear();
    vm.limpiarFiltros();
  }

  Future<String?> _crearIncidencia({
    required String bicicleteroId,
    required String tipo,
    required String descripcion,
    String? bicicletaId,
    List<String> fotos = const <String>[],
  }) async {
    try {
      await vm.crear(
        bicicleteroId: bicicleteroId,
        tipo: tipo,
        descripcion: descripcion,
        bicicletaId: bicicletaId,
        fotos: fotos,
      );

      if (mounted) {
        context.mostrarExito('Incidencia registrada correctamente');
      }
      return null;
    } on ExcepcionApi catch (error) {
      return error.mensaje;
    } catch (_) {
      return mensajeSinConexion;
    }
  }

  Future<void> _abrirFormulario({BorradorIncidencia? borrador}) async {
    final datosFormulario = ref
        .read(datosFormularioIncidenciaProvider(_argsFormulario))
        .valueOrNull;
    if (datosFormulario == null) {
      return;
    }
    if (datosFormulario.bicicleteros.isEmpty) {
      context.mostrarError(
        'No hay un bicicletero disponible para asociar el reporte.',
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => HojaRegistrarIncidencia(
        bicicleteros: datosFormulario.bicicleteros,
        bicicletas: datosFormulario.bicicletas,
        permitirBicicletaPropia: widget.permitirBicicletaPropia,
        onEnviar: _crearIncidencia,
        borrador: borrador,
      ),
    );
  }

  Future<void> _actualizarEstado(
      IncidenciaApp incidencia, String estado) async {
    final respuesta = await _pedirRespuestaGestion(
      incidencia: incidencia,
      estado: estado,
    );

    if (respuesta == null && estado != 'EN_REVISION') {
      return;
    }

    try {
      await vm.actualizarEstado(
        incidenciaId: incidencia.id,
        estado: estado,
        respuesta: respuesta,
      );

      if (mounted) {
        context.mostrarExito(
            'Incidencia ${etiquetaEstadoIncidencia(estado).toLowerCase()}');
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

  Future<void> _recordar(IncidenciaApp incidencia) async {
    try {
      await vm.recordar(incidenciaId: incidencia.id);

      if (mounted) {
        context.mostrarExito('Recordatorio enviado');
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

  Future<String?> _pedirRespuestaGestion({
    required IncidenciaApp incidencia,
    required String estado,
  }) async {
    if (estado == 'EN_REVISION') {
      return '';
    }

    return showDialog<String?>(
      context: context,
      builder: (_) => DialogoRespuestaGestion(
        incidencia: incidencia,
        estado: estado,
        respuestaInicial: incidencia.respuesta ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(incidenciasVersionProvider, (_, __) {
      if (mounted) {
        vm.recargar();
      }
    });
    final estadoIncidencias = ref.watch(_vmProvider);
    final filtros = ref.watch(_filtrosProvider);
    final datosFormulario =
        ref.watch(datosFormularioIncidenciaProvider(_argsFormulario));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListaConFiltros(
        onRefrescar: vm.refrescar,
        cabecera: [
          PanelFiltrosIncidencias(
            estado: filtros.estado,
            tipo: filtros.tipo,
            controladorBusqueda: controladorBusqueda,
            onLimpiar: _limpiarFiltros,
            onEstado: vm.cambiarEstado,
            onTipo: vm.cambiarTipo,
            onBuscar: _programarBusqueda,
            onRegistrar: datosFormulario.isLoading ? null : _abrirFormulario,
          ),
        ],
        contenido: _contenidoIncidencias(estadoIncidencias),
      ),
    );
  }

  Widget _contenidoIncidencias(AsyncValue<List<IncidenciaApp>> estado) {
    final ultimoDato = estado.valueOrNull;

    if (estado.isLoading && ultimoDato == null) {
      return const SliverCargando();
    }

    if (estado.hasError && ultimoDato == null) {
      return SliverToBoxAdapter(
        child: TarjetaAccion(
          icono: Icons.error_outline,
          titulo: 'No se pudieron cargar incidencias',
          detalle: 'Revisa tu conexión y toca para reintentar.',
          color: ColoresUbb.rojoInstitucional,
          onTap: _recargar,
        ),
      );
    }

    final incidencias = ultimoDato ?? const <IncidenciaApp>[];

    if (incidencias.isEmpty) {
      return const SliverEspacioRestante(
        child: EstadoLista(
          icono: Icons.report_problem_outlined,
          titulo: 'Sin incidencias',
          detalle: 'Cuando exista un reporte operativo aparecerá aquí.',
        ),
      );
    }

    return SliverList.list(
      children: [
        if (vm.desactualizado)
          const ListTile(
            leading: Icon(Icons.cloud_off_outlined),
            title: Text('Datos sin actualizar. Desliza para reintentar.'),
          ),
        ...incidencias.map(
          (incidencia) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TarjetaIncidencia(
              incidencia: incidencia,
              mostrarReportante: widget.mostrarReportante,
              puedeGestionar: widget.puedeGestionar,
              gestionGuardia: widget.gestionGuardia,
              mostrarRecordar: !widget.mostrarReportante,
              onActualizarEstado: (estado) =>
                  _actualizarEstado(incidencia, estado),
              onRecordar: () => _recordar(incidencia),
              onEsperaCumplida: vm.refrescar,
            ),
          ),
        ),
        if (vm.hayMas)
          OutlinedButton(
            onPressed: vm.cargandoMas ? null : vm.cargarMas,
            child:
                Text(vm.cargandoMas ? 'Cargando…' : 'Cargar más incidencias'),
          ),
      ],
    );
  }
}
