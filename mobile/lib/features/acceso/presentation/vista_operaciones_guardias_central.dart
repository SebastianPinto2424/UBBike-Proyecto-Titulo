import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ubbike/features/historial/application/movimientos_vm.dart';
import 'package:ubbike/features/historial/data/historial_modelos.dart';
import 'package:ubbike/features/acceso/application/solicitudes_guardia_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/lista_con_filtros.dart';
import 'package:ubbike/shared/widgets/exportacion_reporte.dart';

import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/shared/modelos/rol_usuario.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';
import 'package:ubbike/shared/widgets/tarjeta_movimiento.dart';
import 'package:ubbike/shared/utils/etiquetas_movimiento.dart';

class _ResumenGuardia {
  int total = 0;
  int denegaciones = 0;
  final bicicleteros = <String>{};
}

String _detalleResumenGuardia(_ResumenGuardia resumen) {
  final bicicleteros = resumen.bicicleteros.toList()..sort();
  final visibles = bicicleteros.take(2).join(', ');
  final restantes = bicicleteros.length - 2;
  final detalleBicicleteros =
      restantes > 0 ? '$visibles y $restantes más' : visibles;

  return [
    '${resumen.total} validaciones',
    '${resumen.denegaciones} denegaciones',
    if (detalleBicicleteros.isNotEmpty) detalleBicicleteros,
  ].join(' | ');
}

Map<String, _ResumenGuardia> _agruparPorGuardia(
  List<MovimientoApp> movimientos,
) {
  final resumen = <String, _ResumenGuardia>{};

  for (final movimiento in movimientos) {
    final guardia = resumen.putIfAbsent(
      movimiento.guardiaNombre,
      _ResumenGuardia.new,
    );

    guardia.total += 1;
    if (movimiento.estado == 'DENEGADO') {
      guardia.denegaciones += 1;
    }
    guardia.bicicleteros.add(movimiento.bicicleteroNombre);
  }

  return resumen;
}

class VistaOperacionesGuardiasCentral extends ConsumerStatefulWidget {
  const VistaOperacionesGuardiasCentral({super.key});

  @override
  ConsumerState<VistaOperacionesGuardiasCentral> createState() =>
      _VistaOperacionesGuardiasCentralState();
}

class _VistaOperacionesGuardiasCentralState
    extends ConsumerState<VistaOperacionesGuardiasCentral> {
  SolicitudesGuardiaVm get vm => ref.read(solicitudesGuardiaVmProvider);
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
    futuroOpciones = ref.read(movimientosCentralVmProvider).opciones();
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
    return ref.read(movimientosCentralVmProvider).listar(
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

  void _mostrarDetalleGuardia(
    String nombre,
    _ResumenGuardia resumen,
    List<MovimientoApp> movimientos,
  ) {
    final ordenados = [...movimientos]
      ..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
    final double alturaInicial =
        (0.42 + ordenados.length * 0.12).clamp(0.42, 0.9).toDouble();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: alturaInicial,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Operaciones de $nombre',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _detalleResumenGuardia(resumen),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ColoresUbb.textoSecundario,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 14),
            ...ordenados.map(
              (movimiento) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TarjetaMovimientoCentral(
                  movimiento: movimiento,
                  mostrarIdentidad: true,
                  mostrarGuardia: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    final resumen = _agruparPorGuardia(movimientos);
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
                detalle: _detalleResumenGuardia(entrada.value),
                color: entrada.value.denegaciones == 0
                    ? ColoresUbb.exito
                    : ColoresUbb.amarilloInstitucional,
                onTap: () => _mostrarDetalleGuardia(
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
