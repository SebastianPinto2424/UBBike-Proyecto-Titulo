import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';

class FiltroActivo {
  const FiltroActivo({required this.etiqueta, required this.onQuitar});

  final String etiqueta;
  final VoidCallback onQuitar;
}

class PanelFiltros extends StatelessWidget {
  const PanelFiltros({
    super.key,
    required this.titulo,
    required this.detalle,
    required this.children,
    this.onLimpiar,
    this.activos = const <FiltroActivo>[],
  });

  final String titulo;
  final String detalle;
  final List<Widget> children;
  final VoidCallback? onLimpiar;
  final List<FiltroActivo> activos;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExpansionTile(
            leading: const Icon(Icons.tune, color: ColoresUbb.azulApp),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (activos.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _ContadorFiltros(cantidad: activos.length),
                ],
              ],
            ),
            subtitle: Text(
              detalle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const SizedBox(height: 6),
              ...children,
              if (onLimpiar != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onLimpiar,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Restablecer filtros'),
                  ),
                ),
              ],
            ],
          ),
          if (activos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filtro in activos)
                    InputChip(
                      label: Text(filtro.etiqueta),
                      onDeleted: filtro.onQuitar,
                      deleteIcon: const Icon(Icons.close, size: 16),
                      deleteButtonTooltipMessage: 'Quitar filtro',
                      visualDensity: VisualDensity.compact,
                      backgroundColor:
                          ColoresUbb.azulApp.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: ColoresUbb.azulApp.withValues(alpha: 0.28),
                      ),
                      labelStyle:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: ColoresUbb.azulNoche,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ContadorFiltros extends StatelessWidget {
  const _ContadorFiltros({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ColoresUbb.azulApp,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$cantidad',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class EtiquetaFiltro extends StatelessWidget {
  const EtiquetaFiltro({super.key, required this.texto, required this.child});

  final String texto;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          texto,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColoresUbb.textoSecundario,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class SegmentadoEnLinea<T extends Object> extends StatelessWidget {
  const SegmentadoEnLinea({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        segments: segments,
        selected: selected,
        onSelectionChanged: onSelectionChanged,
      ),
    );
  }
}

class FiltroChip extends StatelessWidget {
  const FiltroChip({
    super.key,
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onTap,
  });

  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final bool seleccionado = value == selectedValue;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: seleccionado
              ? ColoresUbb.azulApp
              : ColoresUbb.azulApp.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: seleccionado ? Colors.white : ColoresUbb.azulApp,
                fontWeight: seleccionado ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
