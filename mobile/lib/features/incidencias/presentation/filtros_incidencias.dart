import 'package:flutter/material.dart';

import 'package:ubbike/features/incidencias/presentation/etiquetas_incidencia.dart';
import 'package:ubbike/shared/widgets/boton_registrar_compacto.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';

class PanelFiltrosIncidencias extends StatelessWidget {
  const PanelFiltrosIncidencias({
    super.key,
    required this.estado,
    required this.tipo,
    required this.busquedaController,
    required this.onLimpiar,
    required this.onEstado,
    required this.onTipo,
    required this.onBuscar,
    required this.onRegistrar,
  });

  final String estado;
  final String tipo;
  final TextEditingController busquedaController;
  final VoidCallback onLimpiar;
  final ValueChanged<String> onEstado;
  final ValueChanged<String> onTipo;
  final VoidCallback onBuscar;
  final VoidCallback? onRegistrar;

  List<FiltroActivo> _filtrosActivos() {
    final busqueda = busquedaController.text.trim();
    return [
      if (estado != 'TODOS')
        FiltroActivo(
          etiqueta: etiquetaEstadoIncidencia(estado),
          onQuitar: () => onEstado('TODOS'),
        ),
      if (tipo != 'TODOS')
        FiltroActivo(
          etiqueta: etiquetaTipoIncidencia(tipo),
          onQuitar: () => onTipo('TODOS'),
        ),
      if (busqueda.isNotEmpty)
        FiltroActivo(
          etiqueta: 'Busca: $busqueda',
          onQuitar: () {
            busquedaController.clear();
            onBuscar();
          },
        ),
    ];
  }

  String _resumenFiltros() {
    final estadoTexto = etiquetaEstadoIncidencia(estado);
    final tipoTexto =
        tipo == 'TODOS' ? 'Todos los tipos' : etiquetaTipoIncidencia(tipo);
    return '$estadoTexto | $tipoTexto';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: TituloApartado(titulo: 'Incidencias reportadas'),
            ),
            if (onRegistrar != null) ...[
              const SizedBox(width: 12),
              BotonRegistrarCompacto(
                texto: 'Registrar',
                onPressed: onRegistrar!,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: busquedaController,
          textInputAction: TextInputAction.search,
          onChanged: (_) => onBuscar(),
          onSubmitted: (_) => onBuscar(),
          decoration: InputDecoration(
            labelText: 'Buscar incidencia, bicicletero o descripción',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: busquedaController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      busquedaController.clear();
                      onBuscar();
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),
        PanelFiltros(
          titulo: 'Filtros',
          activos: _filtrosActivos(),
          detalle: _resumenFiltros(),
          onLimpiar: onLimpiar,
          children: [
            EtiquetaFiltro(
              texto: 'Estado',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in [
                    'TODOS',
                    'ABIERTAS',
                    'PENDIENTE',
                    'EN_REVISION',
                    'RESUELTA'
                  ])
                    FiltroChip(
                      label: etiquetaEstadoIncidencia(item),
                      value: item,
                      selectedValue: estado,
                      onTap: onEstado,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            EtiquetaFiltro(
              texto: 'Tipo',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FiltroChip(
                    label: 'Todos los tipos',
                    value: 'TODOS',
                    selectedValue: tipo,
                    onTap: onTipo,
                  ),
                  for (final item in tiposIncidencia)
                    FiltroChip(
                      label: etiquetaTipoIncidencia(item),
                      value: item,
                      selectedValue: tipo,
                      onTap: onTipo,
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
