import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/shared/widgets/central_widgets.dart';
import 'package:ubbike/shared/utils/utiles_comun.dart';

class TarjetaMovimientoCentral extends StatelessWidget {
  const TarjetaMovimientoCentral({
    super.key,
    required this.movimiento,
    this.mostrarIdentidad = true,
    this.mostrarGuardia = true,
  });

  final MovimientoApp movimiento;
  final bool mostrarIdentidad;
  final bool mostrarGuardia;

  @override
  Widget build(BuildContext context) {
    final esIngreso = movimiento.tipo == 'INGRESO';
    final confirmado = movimiento.estado == 'CONFIRMADO';
    final tipoTexto = esIngreso ? 'Ingreso' : 'Retiro';
    final motivo = movimiento.motivoDenegacion?.trim();
    final comentario = movimiento.comentarioGuardia?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  esIngreso ? Icons.login : Icons.logout,
                  color: confirmado
                      ? ColoresUbb.exito
                      : ColoresUbb.rojoInstitucional,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    mostrarIdentidad
                        ? '$tipoTexto | ${movimiento.usuarioNombre}'
                        : tipoTexto,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                ChipEstado(
                  texto: confirmado ? 'Confirmado' : 'Denegado',
                  color: confirmado
                      ? ColoresUbb.exito
                      : ColoresUbb.rojoInstitucional,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (mostrarIdentidad) ...[
              FilaDato(
                etiqueta: 'Correo',
                valor: movimiento.usuarioCorreo,
                anchoCompleto: true,
              ),
              FilaDato(
                etiqueta: 'RUT',
                valor: movimiento.usuarioRut ?? 'Sin RUT',
              ),
            ],
            FilaDato(
              etiqueta: 'Bicicleta',
              valor: movimiento.bicicletaDescripcion,
            ),
            if (movimiento.bicicletaMarca != null &&
                movimiento.bicicletaMarca!.trim().isNotEmpty)
              FilaDato(
                etiqueta: 'Marca',
                valor: movimiento.bicicletaMarca!,
              ),
            if (movimiento.bicicletaModelo != null &&
                movimiento.bicicletaModelo!.trim().isNotEmpty)
              FilaDato(
                etiqueta: 'Modelo',
                valor: movimiento.bicicletaModelo!,
              ),
            if (movimiento.bicicletaColor != null &&
                movimiento.bicicletaColor!.trim().isNotEmpty)
              FilaDato(
                etiqueta: 'Color',
                valor: movimiento.bicicletaColor!,
              ),
            if (movimiento.bicicletaAro != null &&
                movimiento.bicicletaAro!.trim().isNotEmpty)
              FilaDato(
                etiqueta: 'Aro',
                valor: movimiento.bicicletaAro!,
              ),
            if (movimiento.bicicletaNumeroSerie != null &&
                movimiento.bicicletaNumeroSerie!.trim().isNotEmpty)
              FilaDato(
                etiqueta: 'N° de serie',
                valor: movimiento.bicicletaNumeroSerie!,
              ),
            FilaDato(
              etiqueta: 'Bicicletero',
              valor: movimiento.bicicleteroNombre,
              anchoCompleto: true,
            ),
            if (mostrarGuardia)
              FilaDato(etiqueta: 'Guardia', valor: movimiento.guardiaNombre),
            FilaDato(
              etiqueta: 'Fecha',
              valor: formatearFecha(movimiento.creadoEn),
            ),
            FilaDato(
              etiqueta: 'Hora',
              valor: formatearHora(movimiento.creadoEn),
            ),
            FilaDato(
              etiqueta: 'Método',
              valor: etiquetaOrigenMovimientoFiltro(movimiento.origen),
            ),
            if (motivo != null && motivo.isNotEmpty)
              FilaDato(
                etiqueta: 'Motivo de rechazo',
                valor: motivo,
                anchoCompleto: true,
                valorColor: ColoresUbb.rojoInstitucional,
                valorPeso: FontWeight.w700,
              ),
            if (comentario != null && comentario.isNotEmpty)
              FilaDato(
                etiqueta: 'Comentario guardia',
                valor: comentario,
                anchoCompleto: true,
                valorColor: ColoresUbb.textoSecundario,
                valorPeso: FontWeight.w700,
              ),
          ],
        ),
      ),
    );
  }
}

class PanelFiltros extends StatelessWidget {
  const PanelFiltros({
    super.key,
    required this.titulo,
    required this.detalle,
    required this.children,
    this.onLimpiar,
  });

  final String titulo;
  final String detalle;
  final List<Widget> children;
  final VoidCallback? onLimpiar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.tune, color: ColoresUbb.azulApp),
        title: Text(
          titulo,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
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

String etiquetaPeriodoFiltro(String periodo) {
  return switch (periodo) {
    'DIA' => 'Día',
    'SEMANA' => 'Semana',
    'MES' => 'Mes',
    'ANIO' => 'Año',
    _ => periodo,
  };
}

String etiquetaTipoMovimientoFiltro(String tipo) {
  return switch (tipo) {
    'TODOS' => 'Todos los movimientos',
    'INGRESO' => 'Ingresos',
    'RETIRO' => 'Retiros',
    _ => tipo,
  };
}

String etiquetaEstadoMovimientoFiltro(String estado) {
  return switch (estado) {
    'TODOS' => 'Todos los resultados',
    'CONFIRMADO' => 'Confirmados',
    'DENEGADO' => 'Denegados',
    _ => estado,
  };
}

String etiquetaOrigenMovimientoFiltro(String origen) {
  return switch (origen) {
    'TODOS' => 'Todos los orígenes',
    'QR' => 'QR',
    'MANUAL' => 'Manual',
    _ => origen,
  };
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
