import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ubbike/shared/modelos/historial_modelos.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';

class ControlesFiltrosMovimientos extends StatelessWidget {
  const ControlesFiltrosMovimientos({
    super.key,
    required this.periodo,
    required this.tipo,
    required this.estado,
    required this.origen,
    required this.fechaDesde,
    required this.fechaHasta,
    required this.bicicleteroId,
    required this.guardiaId,
    required this.opciones,
    required this.onPeriodo,
    required this.onTipo,
    required this.onEstado,
    required this.onOrigen,
    required this.onSeleccionarFecha,
    required this.onQuitarRango,
    required this.onBicicletero,
    required this.onGuardia,
  });

  final String periodo;
  final String tipo;
  final String estado;
  final String origen;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final String? bicicleteroId;
  final String? guardiaId;

  final Future<OpcionesHistorialApp>? opciones;
  final ValueChanged<String> onPeriodo;
  final ValueChanged<String> onTipo;
  final ValueChanged<String> onEstado;
  final ValueChanged<String> onOrigen;
  final void Function({required bool esDesde}) onSeleccionarFecha;
  final VoidCallback onQuitarRango;
  final void Function(String? id, String? nombre) onBicicletero;
  final void Function(String? id, String? nombre) onGuardia;

  @override
  Widget build(BuildContext context) {
    final opciones = this.opciones;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
            onSeleccion: onPeriodo,
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
                      onPressed: () => onSeleccionarFecha(esDesde: true),
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        fechaDesde == null
                            ? 'Desde'
                            : formatearFechaCorta(fechaDesde!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onSeleccionarFecha(esDesde: false),
                      icon:
                          const Icon(Icons.event_available_outlined, size: 18),
                      label: Text(
                        fechaHasta == null
                            ? 'Hasta'
                            : formatearFechaCorta(fechaHasta!),
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
                    onPressed: onQuitarRango,
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
            seleccionado: tipo,
            onSeleccion: onTipo,
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
            seleccionado: estado,
            onSeleccion: onEstado,
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
            seleccionado: origen,
            onSeleccion: onOrigen,
          ),
        ),
        if (opciones != null) ...[
          const SizedBox(height: 12),
          FutureBuilder<OpcionesHistorialApp>(
            future: opciones,
            builder: (context, snapshot) {
              final datos = snapshot.data;
              if (datos == null) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SelectorOpcion(
                    etiqueta: 'Bicicletero',
                    valor: bicicleteroId,
                    opciones: {
                      for (final b in datos.bicicleteros) b.id: b.nombre,
                    },
                    onChanged: onBicicletero,
                  ),
                  const SizedBox(height: 12),
                  _SelectorOpcion(
                    etiqueta: 'Guardia',
                    valor: guardiaId,
                    opciones: {
                      for (final g in datos.guardias) g.id: g.nombre,
                    },
                    onChanged: onGuardia,
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _SelectorOpcion extends StatelessWidget {
  const _SelectorOpcion({
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.onChanged,
  });

  final String etiqueta;
  final String? valor;
  final Map<String, String> opciones;
  final void Function(String? id, String? nombre) onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownAnclado<String>(
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          menuMaxHeight: 300,
          value: valor,
          decoration: InputDecoration(labelText: etiqueta),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos')),
            for (final opcion in opciones.entries)
              DropdownMenuItem(value: opcion.key, child: Text(opcion.value)),
          ],
          onChanged: (id) => onChanged(id, id == null ? null : opciones[id]),
        );
      },
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

String formatearFechaCorta(DateTime fecha) {
  final local = fecha.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  return '$dia/$mes/${local.year}';
}
