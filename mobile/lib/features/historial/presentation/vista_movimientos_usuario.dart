import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/features/historial/application/movimientos_vm.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/features/historial/presentation/widgets_movimientos.dart';

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

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(movimientosUsuarioVmProvider);
    final filtros = ref.watch(filtrosMovimientosUsuarioProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: Builder(
              builder: (context) {
                final ultimoDato = estado.valueOrNull;
                final cargandoInicial = estado.isLoading && ultimoDato == null;
                if (cargandoInicial) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: const [
                      SizedBox(
                        height: 180,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  );
                }
                if (estado.hasError && ultimoDato == null) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      TarjetaAccion(
                        icono: Icons.error_outline,
                        titulo: 'No se pudieron cargar movimientos',
                        detalle: 'Toca para reintentar.',
                        color: ColoresUbb.rojoInstitucional,
                        onTap: _recargar,
                      ),
                    ],
                  );
                }
                final movimientos = ultimoDato ?? const <MovimientoApp>[];
                if (movimientos.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: const [
                      EstadoLista(
                        icono: Icons.history,
                        titulo: 'Sin movimientos',
                        detalle: 'Tus ingresos y retiros aparecerán aquí.',
                      ),
                    ],
                  );
                }
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
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
                      const Text(
                          'No pudimos actualizar. Se muestran los últimos datos.'),
                    if (vm.hayMas)
                      OutlinedButton(
                        onPressed: vm.cargandoMas ? null : vm.cargarMas,
                        child: Text(vm.cargandoMas
                            ? 'Cargando…'
                            : 'Cargar más movimientos'),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
