import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/features/historial/application/movimientos_vm.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/lista_con_filtros.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';
import 'package:ubbike/shared/widgets/tarjeta_movimiento.dart';
import 'package:ubbike/shared/utils/etiquetas_movimiento.dart';

class VistaMovimientosUsuario extends ConsumerStatefulWidget {
  const VistaMovimientosUsuario({super.key});

  @override
  ConsumerState<VistaMovimientosUsuario> createState() =>
      _VistaMovimientosUsuarioState();
}

class _VistaMovimientosUsuarioState
    extends ConsumerState<VistaMovimientosUsuario> {
  final filtroController = TextEditingController();

  MovimientosUsuarioVm get vm =>
      ref.read(movimientosUsuarioVmProvider.notifier);

  @override
  void dispose() {
    filtroController.dispose();
    super.dispose();
  }

  void _recargar() {
    vm.recargar();
  }

  void _programarBusqueda() {
    setState(() {});
    vm.buscar(filtroController.text);
  }

  void _limpiarFiltros() {
    filtroController.clear();
    vm.limpiarFiltros();
  }

  String _resumenFiltros(FiltrosMovimientosUsuario filtros) {
    return [
      etiquetaPeriodoFiltro(filtros.periodo),
      etiquetaTipoMovimientoFiltro(filtros.tipo),
      etiquetaEstadoMovimientoFiltro(filtros.estado),
      etiquetaOrigenMovimientoFiltro(filtros.origen),
    ].join(' | ');
  }

  List<FiltroActivo> _filtrosActivos(FiltrosMovimientosUsuario filtros) {
    final busqueda = filtroController.text.trim();
    return [
      if (filtros.periodo != 'MES')
        FiltroActivo(
          etiqueta: etiquetaPeriodoFiltro(filtros.periodo),
          onQuitar: () => vm.cambiarFiltros(periodo: 'MES'),
        ),
      if (filtros.tipo != 'TODOS')
        FiltroActivo(
          etiqueta: etiquetaTipoMovimientoFiltro(filtros.tipo),
          onQuitar: () => vm.cambiarFiltros(tipo: 'TODOS'),
        ),
      if (filtros.estado != 'TODOS')
        FiltroActivo(
          etiqueta: etiquetaEstadoMovimientoFiltro(filtros.estado),
          onQuitar: () => vm.cambiarFiltros(estado: 'TODOS'),
        ),
      if (filtros.origen != 'TODOS')
        FiltroActivo(
          etiqueta: etiquetaOrigenMovimientoFiltro(filtros.origen),
          onQuitar: () => vm.cambiarFiltros(origen: 'TODOS'),
        ),
      if (busqueda.isNotEmpty)
        FiltroActivo(
          etiqueta: 'Busca: $busqueda',
          onQuitar: () {
            filtroController.clear();
            _recargar();
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(movimientosUsuarioVmProvider);
    final filtros = ref.watch(filtrosMovimientosUsuarioProvider);

    return ListaConFiltros(
      onRefrescar: () async => _recargar(),
      cabecera: [
        const TituloApartado(titulo: 'Mis movimientos'),
        const SizedBox(height: 10),
        TextField(
          controller: filtroController,
          decoration: InputDecoration(
            labelText: 'Buscar por bicicleta, bicicletero o guardia',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: filtroController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar busqueda',
                    onPressed: () {
                      filtroController.clear();
                      _recargar();
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (_) => _programarBusqueda(),
        ),
        const SizedBox(height: 10),
        PanelFiltros(
          titulo: 'Filtros',
          activos: _filtrosActivos(filtros),
          detalle: _resumenFiltros(filtros),
          onLimpiar: _limpiarFiltros,
          children: [
            EtiquetaFiltro(
              texto: 'Período',
              child: SegmentadoEnLinea<String>(
                segments: const [
                  ButtonSegment(value: 'DIA', label: Text('Día')),
                  ButtonSegment(value: 'SEMANA', label: Text('Semana')),
                  ButtonSegment(value: 'MES', label: Text('Mes')),
                  ButtonSegment(value: 'ANIO', label: Text('Año')),
                ],
                selected: {filtros.periodo},
                onSelectionChanged: (valor) =>
                    vm.cambiarFiltros(periodo: valor.first),
              ),
            ),
            const SizedBox(height: 12),
            EtiquetaFiltro(
              texto: 'Tipo',
              child: SegmentadoEnLinea<String>(
                segments: const [
                  ButtonSegment(value: 'TODOS', label: Text('Todos')),
                  ButtonSegment(value: 'INGRESO', label: Text('Ingresos')),
                  ButtonSegment(value: 'RETIRO', label: Text('Retiros')),
                ],
                selected: {filtros.tipo},
                onSelectionChanged: (valor) =>
                    vm.cambiarFiltros(tipo: valor.first),
              ),
            ),
            const SizedBox(height: 12),
            EtiquetaFiltro(
              texto: 'Resultado',
              child: SegmentadoEnLinea<String>(
                segments: const [
                  ButtonSegment(value: 'TODOS', label: Text('Todos')),
                  ButtonSegment(
                      value: 'CONFIRMADO', label: Text('Confirmados')),
                  ButtonSegment(value: 'DENEGADO', label: Text('Denegados')),
                ],
                selected: {filtros.estado},
                onSelectionChanged: (valor) =>
                    vm.cambiarFiltros(estado: valor.first),
              ),
            ),
            const SizedBox(height: 12),
            EtiquetaFiltro(
              texto: 'Origen',
              child: SegmentadoEnLinea<String>(
                segments: const [
                  ButtonSegment(value: 'TODOS', label: Text('Todos')),
                  ButtonSegment(value: 'QR', label: Text('QR')),
                  ButtonSegment(value: 'MANUAL', label: Text('Manual')),
                ],
                selected: {filtros.origen},
                onSelectionChanged: (valor) =>
                    vm.cambiarFiltros(origen: valor.first),
              ),
            ),
          ],
        ),
      ],
      contenido: _contenidoMovimientos(estado),
    );
  }

  Widget _contenidoMovimientos(AsyncValue<List<MovimientoApp>> estado) {
    final ultimoDato = estado.valueOrNull;

    if (estado.isLoading && ultimoDato == null) {
      return const SliverCargando();
    }

    if (estado.hasError && ultimoDato == null) {
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

    final movimientos = ultimoDato ?? const <MovimientoApp>[];
    if (movimientos.isEmpty) {
      return const SliverEspacioRestante(
        child: EstadoLista(
          icono: Icons.history,
          titulo: 'Sin movimientos',
          detalle: 'Tus ingresos y retiros aparecerán aquí.',
        ),
      );
    }

    return SliverList.list(
      children: [
        ...movimientos.map(
          (movimiento) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TarjetaMovimientoCentral(
              movimiento: movimiento,
              mostrarIdentidad: false,
            ),
          ),
        ),
        if (vm.desactualizado)
          const Text('No pudimos actualizar. Se muestran los últimos datos.'),
        if (vm.hayMas)
          OutlinedButton(
            onPressed: vm.cargandoMas ? null : vm.cargarMas,
            child:
                Text(vm.cargandoMas ? 'Cargando…' : 'Cargar más movimientos'),
          ),
      ],
    );
  }
}
