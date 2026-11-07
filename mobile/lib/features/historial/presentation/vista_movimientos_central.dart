import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/historial/application/movimientos_vm.dart';
import 'package:ubbike/features/historial/presentation/controles_filtros_movimientos.dart';
import 'package:ubbike/features/historial/presentation/exportacion_reporte.dart';
import 'package:ubbike/features/historial/presentation/panel_exportar_reporte.dart';
import 'package:ubbike/features/historial/presentation/pie_lista_movimientos.dart';
import 'package:ubbike/shared/modelos/historial_modelos.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/utilidades/etiquetas_movimiento.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';
import 'package:ubbike/shared/widgets/lista_con_filtros.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/tarjeta_movimiento.dart';

class VistaMovimientosCentral extends ConsumerStatefulWidget {
  const VistaMovimientosCentral({super.key});

  @override
  ConsumerState<VistaMovimientosCentral> createState() =>
      _VistaMovimientosCentralState();
}

class _VistaMovimientosCentralState
    extends ConsumerState<VistaMovimientosCentral> {
  MovimientosCentralVm get vm => ref.read(movimientosCentralVmProvider);
  static const int _tamanoPagina = 50;

  int paginaActual = 1;
  bool hayMasPaginas = false;
  bool cargandoMas = false;
  int totalMovimientos = 0;
  List<MovimientoApp> acumulados = const [];

  final controladorFiltro = TextEditingController();
  Timer? temporizadorBusqueda;
  String periodo = 'SEMANA';
  String tipoMovimiento = 'TODOS';
  String estadoMovimiento = 'TODOS';
  String origenMovimiento = 'TODOS';
  String? bicicleteroId;
  String? bicicleteroNombre;
  String? guardiaId;
  String? guardiaNombre;
  DateTime? fechaDesde;
  DateTime? fechaHasta;
  String? formatoExportacion;
  bool exportarAbierto = false;
  bool exportando = false;
  late Future<List<MovimientoApp>> futuroMovimientos;
  Future<OpcionesHistorialApp>? futuroOpciones;

  bool get _esCentral {
    final sesion = ref.read(sesionProvider).value;
    final rol = sesion is SesionActiva ? sesion.usuario.rol : null;
    return rol == RolUsuario.adminCentral || rol == RolUsuario.administrador;
  }

  bool get _puedeExportar => _esCentral;

  @override
  void initState() {
    super.initState();
    futuroMovimientos = _obtenerPrimeraPagina();
    if (_esCentral) {
      futuroOpciones = vm.opciones();
    }
  }

  @override
  void dispose() {
    temporizadorBusqueda?.cancel();
    controladorFiltro.dispose();
    super.dispose();
  }

  Future<List<MovimientoApp>> _obtenerPrimeraPagina() async {
    final pagina = await vm.listarPagina(
      filtro: controladorFiltro.text,
      periodo: periodo,
      desde: fechaDesde,
      hasta: fechaHasta,
      tipo: tipoMovimiento,
      estado: estadoMovimiento,
      bicicleteroId: bicicleteroId,
      guardiaId: guardiaId,
      origen: origenMovimiento,
      limite: _tamanoPagina,
    );

    paginaActual = pagina.pagina;
    hayMasPaginas = pagina.hayMas;
    totalMovimientos = pagina.total;
    acumulados = pagina.movimientos;
    return acumulados;
  }

  Future<void> _cargarSiguientePagina() async {
    if (cargandoMas || !hayMasPaginas) {
      return;
    }

    setState(() => cargandoMas = true);
    try {
      final siguiente = await vm.listarPagina(
        filtro: controladorFiltro.text,
        periodo: periodo,
        desde: fechaDesde,
        hasta: fechaHasta,
        tipo: tipoMovimiento,
        estado: estadoMovimiento,
        bicicleteroId: bicicleteroId,
        guardiaId: guardiaId,
        origen: origenMovimiento,
        limite: _tamanoPagina,
        pagina: paginaActual + 1,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        acumulados = [...acumulados, ...siguiente.movimientos];
        paginaActual = siguiente.pagina;
        hayMasPaginas = siguiente.hayMas;
        totalMovimientos = siguiente.total;
        futuroMovimientos = Future.value(acumulados);
      });
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError('No se pudieron cargar más movimientos.');
      }
    } finally {
      if (mounted) {
        setState(() => cargandoMas = false);
      }
    }
  }

  Future<void> _refrescarEnSegundoPlano() async {
    try {
      final datos = await _obtenerPrimeraPagina();
      if (mounted) setState(() => futuroMovimientos = Future.value(datos));
    } catch (_) {}
  }

  void _recargar() {
    temporizadorBusqueda?.cancel();
    setState(() {
      futuroMovimientos = _obtenerPrimeraPagina();
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

  List<FiltroActivo> _filtrosActivos() {
    final busqueda = controladorFiltro.text.trim();
    return [
      if (periodo != 'SEMANA')
        FiltroActivo(
          etiqueta: etiquetaPeriodoFiltro(periodo),
          onQuitar: () => _aplicarFiltro(() => periodo = 'SEMANA'),
        ),
      if (fechaDesde != null || fechaHasta != null)
        FiltroActivo(
          etiqueta: _textoRangoFechas(),
          onQuitar: () => _aplicarFiltro(() {
            fechaDesde = null;
            fechaHasta = null;
          }),
        ),
      if (tipoMovimiento != 'TODOS')
        FiltroActivo(
          etiqueta: etiquetaTipoMovimientoFiltro(tipoMovimiento),
          onQuitar: () => _aplicarFiltro(() => tipoMovimiento = 'TODOS'),
        ),
      if (estadoMovimiento != 'TODOS')
        FiltroActivo(
          etiqueta: etiquetaEstadoMovimientoFiltro(estadoMovimiento),
          onQuitar: () => _aplicarFiltro(() => estadoMovimiento = 'TODOS'),
        ),
      if (origenMovimiento != 'TODOS')
        FiltroActivo(
          etiqueta: etiquetaOrigenMovimientoFiltro(origenMovimiento),
          onQuitar: () => _aplicarFiltro(() => origenMovimiento = 'TODOS'),
        ),
      if (bicicleteroId != null)
        FiltroActivo(
          etiqueta: bicicleteroNombre ?? 'Bicicletero seleccionado',
          onQuitar: () => _aplicarFiltro(() {
            bicicleteroId = null;
            bicicleteroNombre = null;
          }),
        ),
      if (guardiaId != null)
        FiltroActivo(
          etiqueta: guardiaNombre ?? 'Guardia seleccionado',
          onQuitar: () => _aplicarFiltro(() {
            guardiaId = null;
            guardiaNombre = null;
          }),
        ),
      if (busqueda.isNotEmpty)
        FiltroActivo(
          etiqueta: 'Busca: $busqueda',
          onQuitar: () {
            temporizadorBusqueda?.cancel();
            controladorFiltro.clear();
            _recargar();
          },
        ),
    ];
  }

  String _resumenFiltros() {
    final busqueda = controladorFiltro.text.trim();
    final partes = [
      etiquetaPeriodoFiltro(periodo),
      if (fechaDesde != null || fechaHasta != null) _textoRangoFechas(),
      etiquetaTipoMovimientoFiltro(tipoMovimiento),
      etiquetaEstadoMovimientoFiltro(estadoMovimiento),
      etiquetaOrigenMovimientoFiltro(origenMovimiento),
      if (bicicleteroId != null) 'Bicicletero seleccionado',
      if (guardiaId != null) 'Guardia seleccionado',
      if (busqueda.isNotEmpty) 'Búsqueda activa',
    ];

    return partes.join(' | ');
  }

  void _aplicarFiltro(VoidCallback cambio) {
    setState(cambio);
    _recargar();
  }

  void _limpiarFiltros() {
    temporizadorBusqueda?.cancel();
    controladorFiltro.clear();
    periodo = 'SEMANA';
    tipoMovimiento = 'TODOS';
    estadoMovimiento = 'TODOS';
    origenMovimiento = 'TODOS';
    bicicleteroId = null;
    bicicleteroNombre = null;
    guardiaId = null;
    guardiaNombre = null;
    fechaDesde = null;
    fechaHasta = null;
    _recargar();
  }

  String _textoRangoFechas() {
    final desde =
        fechaDesde == null ? 'Inicio' : formatearFechaCorta(fechaDesde!);
    final hasta = fechaHasta == null ? 'Hoy' : formatearFechaCorta(fechaHasta!);
    return '$desde a $hasta';
  }

  Future<void> _seleccionarFecha({required bool esDesde}) async {
    final res = await showDatePicker(
      context: context,
      initialDate: (esDesde ? fechaDesde : fechaHasta) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(DateTime.now().year + 1),
      helpText: 'Seleccionar fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (res != null) {
      if (!mounted) {
        return;
      }

      final nuevoDesde = esDesde ? res : fechaDesde;
      final nuevoHasta = esDesde ? fechaHasta : res;

      if (nuevoDesde != null &&
          nuevoHasta != null &&
          nuevoDesde.isAfter(nuevoHasta)) {
        context.mostrarError('El rango de fechas no es válido.');
        return;
      }

      setState(() {
        fechaDesde = nuevoDesde;
        fechaHasta = nuevoHasta;
      });
      _recargar();
    }
  }

  Future<void> _exportarSeleccionado(
    String? formato, {
    AccionReporte accion = AccionReporte.descargar,
  }) async {
    if (formato == null || exportando) {
      return;
    }

    setState(() => exportando = true);
    try {
      await ExportadorReporte(ref).exportar(
        context: context,
        formato: formato,
        resumenFiltros: _resumenFiltros(),
        accion: accion,
        filtros: (
          filtro: controladorFiltro.text,
          periodo: periodo,
          desde: fechaDesde,
          hasta: fechaHasta,
          tipo: tipoMovimiento,
          estado: estadoMovimiento,
          bicicleteroId: bicicleteroId,
          guardiaId: guardiaId,
          origen: origenMovimiento,
        ),
      );
    } finally {
      if (mounted) setState(() => exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(movimientosVersionProvider, (_, __) {
      unawaited(_refrescarEnSegundoPlano());
    });

    return FutureBuilder<List<MovimientoApp>>(
      future: futuroMovimientos,
      builder: (context, snapshot) {
        return ListaConFiltros(
          onRefrescar: () async => _recargar(),
          cabecera: [
            const TituloApartado(titulo: 'Historial'),
            const SizedBox(height: 10),
            TextField(
              controller: controladorFiltro,
              textInputAction: TextInputAction.search,
              onChanged: (_) => _programarBusqueda(),
              onSubmitted: (_) => _recargar(),
              decoration: InputDecoration(
                labelText: 'Buscar por bicicleta, bicicletero o guardia',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controladorFiltro.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          temporizadorBusqueda?.cancel();
                          controladorFiltro.clear();
                          _recargar();
                        },
                      ),
              ),
            ),
            const SizedBox(height: 10),
            PanelFiltros(
              titulo: 'Filtros',
              activos: _filtrosActivos(),
              detalle: _resumenFiltros(),
              onLimpiar: _limpiarFiltros,
              children: [
                ControlesFiltrosMovimientos(
                  periodo: periodo,
                  tipo: tipoMovimiento,
                  estado: estadoMovimiento,
                  origen: origenMovimiento,
                  fechaDesde: fechaDesde,
                  fechaHasta: fechaHasta,
                  bicicleteroId: bicicleteroId,
                  guardiaId: guardiaId,
                  opciones: _esCentral ? futuroOpciones : null,
                  onPeriodo: (valor) => _aplicarFiltro(() => periodo = valor),
                  onTipo: (valor) =>
                      _aplicarFiltro(() => tipoMovimiento = valor),
                  onEstado: (valor) =>
                      _aplicarFiltro(() => estadoMovimiento = valor),
                  onOrigen: (valor) =>
                      _aplicarFiltro(() => origenMovimiento = valor),
                  onSeleccionarFecha: _seleccionarFecha,
                  onQuitarRango: () => _aplicarFiltro(() {
                    fechaDesde = null;
                    fechaHasta = null;
                  }),
                  onBicicletero: (id, nombre) => _aplicarFiltro(() {
                    bicicleteroId = id;
                    bicicleteroNombre = nombre;
                  }),
                  onGuardia: (id, nombre) => _aplicarFiltro(() {
                    guardiaId = id;
                    guardiaNombre = nombre;
                  }),
                ),
              ],
            ),
            if (_puedeExportar) ...[
              const SizedBox(height: 10),
              PanelExportarReporte(
                exportando: exportando,
                expandido: exportarAbierto,
                formatoSeleccionado: formatoExportacion,
                onToggle: () {
                  setState(() => exportarAbierto = !exportarAbierto);
                },
                onFormato: (formato) {
                  setState(() => formatoExportacion = formato);
                },
                onDescargar: () => _exportarSeleccionado(formatoExportacion),
                onCompartir: () => _exportarSeleccionado(
                  formatoExportacion,
                  accion: AccionReporte.compartir,
                ),
              ),
            ],
          ],
          contenido: _contenidoMovimientos(snapshot),
        );
      },
    );
  }

  Widget _contenidoMovimientos(AsyncSnapshot<List<MovimientoApp>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SliverCargando();
    }

    if (snapshot.hasError) {
      return SliverToBoxAdapter(
        child: TarjetaAccion(
          icono: Icons.error_outline,
          titulo: 'No se pudieron cargar movimientos',
          detalle: 'Toca para reintentar.',
          color: ColoresUbb.rojoInstitucional,
          onTap: _recargar,
        ),
      );
    }

    final movimientos = snapshot.data ?? [];
    if (movimientos.isEmpty) {
      return const SliverEspacioRestante(
        child: EstadoLista(
          icono: Icons.history,
          titulo: 'Sin movimientos',
          detalle: 'Los ingresos y retiros que coincidan aparecerán aquí.',
        ),
      );
    }

    return SliverList.builder(
      itemCount: movimientos.length + 1,
      itemBuilder: (context, index) {
        if (index == movimientos.length) {
          return PieListaMovimientos(
            mostrados: movimientos.length,
            total: totalMovimientos,
            hayMas: hayMasPaginas,
            cargando: cargandoMas,
            onCargarMas: _cargarSiguientePagina,
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TarjetaMovimientoCentral(
            movimiento: movimientos[index],
            mostrarIdentidad: true,
          ),
        );
      },
    );
  }
}
