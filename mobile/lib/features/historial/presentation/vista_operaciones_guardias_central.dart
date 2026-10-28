import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/historial/application/movimientos_vm.dart';
import 'package:ubbike/features/historial/application/resumen_guardias.dart';
import 'package:ubbike/features/historial/presentation/hoja_detalle_guardia.dart';
import 'package:ubbike/features/historial/presentation/exportacion_reporte.dart';
import 'package:ubbike/features/historial/presentation/panel_exportar_reporte.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/modelos/historial_modelos.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/utilidades/etiquetas_movimiento.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';
import 'package:ubbike/shared/widgets/lista_con_filtros.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';

class VistaOperacionesGuardiasCentral extends ConsumerStatefulWidget {
  const VistaOperacionesGuardiasCentral({super.key});

  @override
  ConsumerState<VistaOperacionesGuardiasCentral> createState() =>
      _VistaOperacionesGuardiasCentralState();
}

class _VistaOperacionesGuardiasCentralState
    extends ConsumerState<VistaOperacionesGuardiasCentral> {
  MovimientosCentralVm get vm => ref.read(movimientosCentralVmProvider);
  final busquedaController = TextEditingController();
  Timer? temporizadorBusqueda;
  String periodo = 'DIA';
  String estadoMovimiento = 'TODOS';
  BicicleteroApp? bicicleteroSeleccionado;
  String? guardiaId;
  String? guardiaNombre;
  List<BicicleteroApp> bicicleteros = [];
  late Future<List<MovimientoApp>> futuroMovimientos;
  Future<OpcionesHistorialApp>? futuroOpciones;
  String? formatoExportacion;
  bool exportarAbierto = false;
  bool exportando = false;

  @override
  void initState() {
    super.initState();
    futuroMovimientos = _obtenerMovimientos();
    futuroOpciones = vm.opciones();
    _cargarBicicleteros();
  }

  @override
  void dispose() {
    temporizadorBusqueda?.cancel();
    busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarBicicleteros() async {
    try {
      final datos = await vm.listarBicicleteros();
      if (mounted) {
        setState(() => bicicleteros = datos);
      }
    } catch (_) {
      if (mounted) {
        setState(() => bicicleteros = []);
      }
    }
  }

  Future<List<MovimientoApp>> _obtenerMovimientos() {
    final busqueda = busquedaController.text.trim();
    return vm.listar(
      filtro: busqueda.isEmpty ? null : busqueda,
      periodo: periodo,
      estado: estadoMovimiento,
      bicicleteroId: bicicleteroSeleccionado?.id,
      guardiaId: guardiaId,
      limite: 100000,
    );
  }

  void _recargar() {
    setState(() {
      futuroMovimientos = _obtenerMovimientos();
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

  String _resumenFiltros() {
    final busqueda = busquedaController.text.trim();
    return [
      etiquetaPeriodoFiltro(periodo),
      bicicleteroSeleccionado?.nombre ?? 'Todos los bicicleteros',
      guardiaNombre ?? 'Todos los guardias',
      etiquetaEstadoMovimientoFiltro(estadoMovimiento),
      if (busqueda.isNotEmpty) 'Búsqueda activa',
    ].join(' | ');
  }

  List<FiltroActivo> _filtrosActivos() {
    final busqueda = busquedaController.text.trim();
    return [
      if (periodo != 'DIA')
        FiltroActivo(
          etiqueta: etiquetaPeriodoFiltro(periodo),
          onQuitar: () {
            setState(() {
              periodo = 'DIA';
              futuroMovimientos = _obtenerMovimientos();
            });
          },
        ),
      if (bicicleteroSeleccionado != null)
        FiltroActivo(
          etiqueta: bicicleteroSeleccionado!.nombre,
          onQuitar: () {
            setState(() {
              bicicleteroSeleccionado = null;
              futuroMovimientos = _obtenerMovimientos();
            });
          },
        ),
      if (guardiaId != null)
        FiltroActivo(
          etiqueta: guardiaNombre ?? 'Guardia seleccionado',
          onQuitar: () {
            setState(() {
              guardiaId = null;
              guardiaNombre = null;
              futuroMovimientos = _obtenerMovimientos();
            });
          },
        ),
      if (estadoMovimiento != 'TODOS')
        FiltroActivo(
          etiqueta: etiquetaEstadoMovimientoFiltro(estadoMovimiento),
          onQuitar: () {
            setState(() {
              estadoMovimiento = 'TODOS';
              futuroMovimientos = _obtenerMovimientos();
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

  void _limpiarFiltros() {
    temporizadorBusqueda?.cancel();
    busquedaController.clear();
    setState(() {
      periodo = 'DIA';
      estadoMovimiento = 'TODOS';
      bicicleteroSeleccionado = null;
      guardiaId = null;
      guardiaNombre = null;
      futuroMovimientos = _obtenerMovimientos();
    });
  }

  bool get _puedeExportar {
    final sesion = ref.read(sesionProvider).value;
    final rol = sesion is SesionActiva ? sesion.usuario.rol : null;
    return rol == RolUsuario.adminCentral || rol == RolUsuario.administrador;
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
          filtro: busquedaController.text.trim().isEmpty
              ? null
              : busquedaController.text.trim(),
          periodo: periodo,
          desde: null,
          hasta: null,
          tipo: null,
          estado: estadoMovimiento,
          bicicleteroId: bicicleteroSeleccionado?.id,
          guardiaId: guardiaId,
          origen: null,
        ),
      );
    } finally {
      if (mounted) setState(() => exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MovimientoApp>>(
      future: futuroMovimientos,
      builder: (context, snapshot) {
        return ListaConFiltros(
          onRefrescar: () async => _recargar(),
          cabecera: [
            const SizedBox(height: 8),
            const TituloApartado(titulo: 'Operaciones por guardia'),
            const SizedBox(height: 10),
            TextField(
              controller: busquedaController,
              textInputAction: TextInputAction.search,
              onChanged: (_) => _programarBusqueda(),
              onSubmitted: (_) => _recargar(),
              decoration: InputDecoration(
                labelText: 'Buscar por guardia, bicicleta o bicicletero',
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
              titulo: 'Filtros de operaciones',
              activos: _filtrosActivos(),
              detalle: _resumenFiltros(),
              onLimpiar: _limpiarFiltros,
              children: [
                EtiquetaFiltro(
                  texto: 'Periodo',
                  child: SegmentadoEnLinea<String>(
                    segments: const [
                      ButtonSegment(value: 'DIA', label: Text('Día')),
                      ButtonSegment(value: 'SEMANA', label: Text('Semana')),
                      ButtonSegment(value: 'MES', label: Text('Mes')),
                      ButtonSegment(value: 'ANIO', label: Text('Año')),
                    ],
                    selected: {periodo},
                    onSelectionChanged: (valor) {
                      setState(() {
                        periodo = valor.first;
                        futuroMovimientos = _obtenerMovimientos();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                DropdownAnclado<BicicleteroApp?>(
                  key: ValueKey(bicicleteroSeleccionado?.id ?? 'todos'),
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(16),
                  menuMaxHeight: 300,
                  value: bicicleteroSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Bicicletero',
                  ),
                  items: [
                    const DropdownMenuItem<BicicleteroApp?>(
                      value: null,
                      child: Text('Todos los bicicleteros'),
                    ),
                    ...bicicleteros.map(
                      (bicicletero) => DropdownMenuItem<BicicleteroApp?>(
                        value: bicicletero,
                        child: Text(
                          bicicletero.nombre,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (valor) {
                    setState(() {
                      bicicleteroSeleccionado = valor;
                      futuroMovimientos = _obtenerMovimientos();
                    });
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<OpcionesHistorialApp>(
                  future: futuroOpciones,
                  builder: (context, snapshot) {
                    final guardias = snapshot.data?.guardias ?? const [];
                    return DropdownAnclado<String>(
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      menuMaxHeight: 300,
                      value: guardiaId,
                      decoration: const InputDecoration(labelText: 'Guardia'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Todos los guardias'),
                        ),
                        ...guardias.map(
                          (guardia) => DropdownMenuItem<String>(
                            value: guardia.id,
                            child: Text(
                              guardia.nombre,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (valor) {
                        setState(() {
                          guardiaId = valor;
                          guardiaNombre = valor == null
                              ? null
                              : guardias
                                  .firstWhere((g) => g.id == valor)
                                  .nombre;
                          futuroMovimientos = _obtenerMovimientos();
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                EtiquetaFiltro(
                  texto: 'Resultado',
                  child: SegmentadoEnLinea<String>(
                    segments: const [
                      ButtonSegment(value: 'TODOS', label: Text('Todos')),
                      ButtonSegment(
                          value: 'CONFIRMADO', label: Text('Confirmados')),
                      ButtonSegment(
                          value: 'DENEGADO', label: Text('Denegados')),
                    ],
                    selected: {estadoMovimiento},
                    onSelectionChanged: (valor) {
                      setState(() {
                        estadoMovimiento = valor.first;
                        futuroMovimientos = _obtenerMovimientos();
                      });
                    },
                  ),
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
          contenido: _contenidoOperaciones(snapshot),
        );
      },
    );
  }

  Widget _contenidoOperaciones(AsyncSnapshot<List<MovimientoApp>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SliverCargando();
    }

    if (snapshot.hasError) {
      return SliverToBoxAdapter(
        child: TarjetaAccion(
          icono: Icons.error_outline,
          titulo: 'No se pudieron cargar operaciones',
          detalle: 'Revisa tu conexión y toca para reintentar.',
          color: ColoresUbb.rojoInstitucional,
          onTap: _recargar,
        ),
      );
    }

    final movimientos = snapshot.data ?? [];
    final resumen = agruparPorGuardia(movimientos);
    final entradas = resumen.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    if (entradas.isEmpty) {
      return const SliverEspacioRestante(
        child: EstadoLista(
          icono: Icons.security_outlined,
          titulo: 'Sin operaciones',
          detalle: 'No hay validaciones para el periodo seleccionado.',
        ),
      );
    }

    return SliverList.list(
      children: entradas
          .map(
            (entrada) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaAccion(
                icono: Icons.verified_user_outlined,
                titulo: entrada.key,
                detalle: detalleResumenGuardia(entrada.value),
                color: entrada.value.denegaciones == 0
                    ? ColoresUbb.exito
                    : ColoresUbb.amarilloInstitucional,
                onTap: () => mostrarDetalleGuardia(
                  context,
                  entrada.key,
                  entrada.value,
                  movimientos
                      .where((m) => m.guardiaNombre == entrada.key)
                      .toList(),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
