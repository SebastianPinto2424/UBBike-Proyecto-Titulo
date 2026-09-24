import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/features/historial/application/movimientos_vm.dart';
import 'package:ubbike/shared/widgets/exportacion_reporte.dart';

import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/historial/data/historial_modelos.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/modelos/rol_usuario.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/lista_con_filtros.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';
import 'package:ubbike/shared/widgets/tarjeta_movimiento.dart';
import 'package:ubbike/shared/utils/etiquetas_movimiento.dart';

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

  final filtroController = TextEditingController();
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

  bool get _puedeExportar {
    final sesion = ref.read(sesionProvider).value;
    final rol = sesion is SesionActiva ? sesion.usuario.rol : null;
    return rol == RolUsuario.adminCentral || rol == RolUsuario.administrador;
  }

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
    filtroController.dispose();
    super.dispose();
  }

  Future<List<MovimientoApp>> _obtenerPrimeraPagina() async {
    final pagina = await vm.listarPagina(
      filtro: filtroController.text,
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
        filtro: filtroController.text,
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
    final busqueda = filtroController.text.trim();
    return [
      if (periodo != 'SEMANA')
        FiltroActivo(
          etiqueta: etiquetaPeriodoFiltro(periodo),
          onQuitar: () {
            setState(() => periodo = 'SEMANA');
            _recargar();
          },
        ),
      if (fechaDesde != null || fechaHasta != null)
        FiltroActivo(
          etiqueta: _textoRangoFechas(),
          onQuitar: () {
            setState(() {
              fechaDesde = null;
              fechaHasta = null;
            });
            _recargar();
          },
        ),
      if (tipoMovimiento != 'TODOS')
        FiltroActivo(
          etiqueta: etiquetaTipoMovimientoFiltro(tipoMovimiento),
          onQuitar: () {
            setState(() => tipoMovimiento = 'TODOS');
            _recargar();
          },
        ),
      if (estadoMovimiento != 'TODOS')
        FiltroActivo(
          etiqueta: etiquetaEstadoMovimientoFiltro(estadoMovimiento),
          onQuitar: () {
            setState(() => estadoMovimiento = 'TODOS');
            _recargar();
          },
        ),
      if (origenMovimiento != 'TODOS')
        FiltroActivo(
          etiqueta: etiquetaOrigenMovimientoFiltro(origenMovimiento),
          onQuitar: () {
            setState(() => origenMovimiento = 'TODOS');
            _recargar();
          },
        ),
      if (bicicleteroId != null)
        FiltroActivo(
          etiqueta: bicicleteroNombre ?? 'Bicicletero seleccionado',
          onQuitar: () {
            setState(() {
              bicicleteroId = null;
              bicicleteroNombre = null;
            });
            _recargar();
          },
        ),
      if (guardiaId != null)
        FiltroActivo(
          etiqueta: guardiaNombre ?? 'Guardia seleccionado',
          onQuitar: () {
            setState(() {
              guardiaId = null;
              guardiaNombre = null;
            });
            _recargar();
          },
        ),
      if (busqueda.isNotEmpty)
        FiltroActivo(
          etiqueta: 'Busca: $busqueda',
          onQuitar: () {
            temporizadorBusqueda?.cancel();
            filtroController.clear();
            _recargar();
          },
        ),
    ];
  }

  String _resumenFiltros() {
    final busqueda = filtroController.text.trim();
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

  void _limpiarFiltros() {
    temporizadorBusqueda?.cancel();
    filtroController.clear();
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
        fechaDesde == null ? 'Inicio' : _formatearFechaCorta(fechaDesde!);
    final hasta =
        fechaHasta == null ? 'Hoy' : _formatearFechaCorta(fechaHasta!);
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

  Future<void> _exportarSeleccionado(String? formato) async {
    if (formato == null || exportando) {
      return;
    }

    setState(() => exportando = true);
    try {
      await ExportadorReporte(ref).exportar(
        context: context,
        formato: formato,
        resumenFiltros: _resumenFiltros(),
        filtros: (
          filtro: filtroController.text,
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

  List<Widget> _controlesFiltros() {
    return [
      EtiquetaFiltro(
        texto: 'Período',
        child: _ChipsFiltro(
          opciones: const {
            'DIA': 'Día',
            'SEMANA': 'Semana',
            'MES': 'Mes',
            'ANIO': 'Año',
          },
          seleccionado: periodo,
          onSeleccion: (valor) {
            setState(() => periodo = valor);
            _recargar();
          },
        ),
      ),
      const SizedBox(height: 12),
      EtiquetaFiltro(
        texto: 'Rango exacto',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _seleccionarFecha(esDesde: true),
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      fechaDesde == null
                          ? 'Desde'
                          : _formatearFechaCorta(fechaDesde!),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _seleccionarFecha(esDesde: false),
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: Text(
                      fechaHasta == null
                          ? 'Hasta'
                          : _formatearFechaCorta(fechaHasta!),
                    ),
                  ),
                ),
              ],
            ),
            if (fechaDesde != null || fechaHasta != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      fechaDesde = null;
                      fechaHasta = null;
                    });
                    _recargar();
                  },
                  child: const Text('Quitar rango'),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      EtiquetaFiltro(
        texto: 'Tipo de movimiento',
        child: _ChipsFiltro(
          opciones: const {
            'TODOS': 'Todos',
            'INGRESO': 'Ingresos',
            'RETIRO': 'Retiros',
          },
          seleccionado: tipoMovimiento,
          onSeleccion: (valor) {
            setState(() => tipoMovimiento = valor);
            _recargar();
          },
        ),
      ),
      const SizedBox(height: 12),
      EtiquetaFiltro(
        texto: 'Resultado',
        child: _ChipsFiltro(
          opciones: const {
            'TODOS': 'Todos',
            'CONFIRMADO': 'Confirmados',
            'DENEGADO': 'Denegados',
          },
          seleccionado: estadoMovimiento,
          onSeleccion: (valor) {
            setState(() => estadoMovimiento = valor);
            _recargar();
          },
        ),
      ),
      const SizedBox(height: 12),
      EtiquetaFiltro(
        texto: 'Origen',
        child: _ChipsFiltro(
          opciones: const {
            'TODOS': 'Todos',
            'QR': 'QR',
            'MANUAL': 'Manual',
          },
          seleccionado: origenMovimiento,
          onSeleccion: (valor) {
            setState(() => origenMovimiento = valor);
            _recargar();
          },
        ),
      ),
      if (_esCentral && futuroOpciones != null) ...[
        const SizedBox(height: 12),
        FutureBuilder<OpcionesHistorialApp>(
          future: futuroOpciones,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }
            final opciones = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return DropdownAnclado<String>(
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      menuMaxHeight: 300,
                      value: bicicleteroId,
                      decoration:
                          const InputDecoration(labelText: 'Bicicletero'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todos'),
                        ),
                        ...opciones.bicicleteros.map(
                          (b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.nombre),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          bicicleteroId = v;
                          bicicleteroNombre = v == null
                              ? null
                              : opciones.bicicleteros
                                  .firstWhere((b) => b.id == v)
                                  .nombre;
                        });
                        _recargar();
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return DropdownAnclado<String>(
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      menuMaxHeight: 300,
                      value: guardiaId,
                      decoration: const InputDecoration(labelText: 'Guardia'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todos'),
                        ),
                        ...opciones.guardias.map(
                          (g) => DropdownMenuItem(
                            value: g.id,
                            child: Text(g.nombre),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          guardiaId = v;
                          guardiaNombre = v == null
                              ? null
                              : opciones.guardias
                                  .firstWhere((g) => g.id == v)
                                  .nombre;
                        });
                        _recargar();
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MovimientoApp>>(
      future: futuroMovimientos,
      builder: (context, snapshot) {
        return ListaConFiltros(
          onRefrescar: () async => _recargar(),
          cabecera: [
            const TituloApartado(titulo: 'Historial'),
            const SizedBox(height: 10),
            TextField(
              controller: filtroController,
              textInputAction: TextInputAction.search,
              onChanged: (_) => _programarBusqueda(),
              onSubmitted: (_) => _recargar(),
              decoration: InputDecoration(
                labelText: 'Buscar por bicicleta, bicicletero o guardia',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: filtroController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          temporizadorBusqueda?.cancel();
                          filtroController.clear();
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
              children: _controlesFiltros(),
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
          return _PieListaMovimientos(
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

class _PieListaMovimientos extends StatelessWidget {
  const _PieListaMovimientos({
    required this.mostrados,
    required this.total,
    required this.hayMas,
    required this.cargando,
    required this.onCargarMas,
  });

  final int mostrados;
  final int total;
  final bool hayMas;
  final bool cargando;
  final VoidCallback onCargarMas;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hayMas
                ? 'Mostrando $mostrados de $total movimientos'
                : 'Mostrando los $total movimientos del filtro',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColoresUbb.textoSecundario,
                ),
          ),
          if (hayMas) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: cargando ? null : onCargarMas,
              icon: cargando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(cargando ? 'Cargando' : 'Cargar más'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipsFiltro extends StatelessWidget {
  const _ChipsFiltro({
    required this.opciones,
    required this.seleccionado,
    required this.onSeleccion,
  });

  final Map<String, String> opciones;
  final String seleccionado;
  final ValueChanged<String> onSeleccion;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opciones.entries
          .map(
            (opcion) => FiltroChip(
              label: opcion.value,
              value: opcion.key,
              selectedValue: seleccionado,
              onTap: onSeleccion,
            ),
          )
          .toList(),
    );
  }
}

String _formatearFechaCorta(DateTime fecha) {
  final local = fecha.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  return '$dia/$mes/${local.year}';
}
