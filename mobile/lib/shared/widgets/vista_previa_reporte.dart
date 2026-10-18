import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';

class VistaPreviaReporte extends StatelessWidget {
  const VistaPreviaReporte({
    super.key,
    required this.formato,
    required this.encabezados,
    required this.filas,
    required this.totalRegistros,
    required this.resumenFiltros,
    this.columnasAdicionales = const [],
    this.textoConfirmar = 'Descargar',
    this.iconoConfirmar = Icons.download_outlined,
  });

  final String formato;
  final List<String> encabezados;
  final List<List<String>> filas;
  final int totalRegistros;
  final String resumenFiltros;

  final List<String> columnasAdicionales;
  final String textoConfirmar;
  final IconData iconoConfirmar;

  static const _maximoFilas = 20;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final muestra = filas.take(_maximoFilas).toList();
    final restantes = totalRegistros - muestra.length;

    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Vista previa · $formato',
              style: tema.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
              '$totalRegistros ${totalRegistros == 1 ? 'registro' : 'registros'} · $resumenFiltros',
              style: tema.textTheme.bodySmall),
          const SizedBox(height: 14),
          if (totalRegistros == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(children: [
                const Icon(Icons.filter_alt_off_outlined,
                    size: 38, color: ColoresUbb.textoSecundario),
                const SizedBox(height: 10),
                Text('No hay movimientos con estos filtros.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text('Ajusta los filtros antes de descargar.',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodySmall),
              ]),
            )
          else ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .42),
              child: Card(
                margin: EdgeInsets.zero,
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 38,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 44,
                      columnSpacing: 18,
                      columns: encabezados
                          .map((titulo) => DataColumn(
                              label: Text(titulo,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12))))
                          .toList(),
                      rows: muestra
                          .map((fila) => DataRow(
                              cells: fila
                                  .map((valor) => DataCell(Text(valor,
                                      style: const TextStyle(fontSize: 12))))
                                  .toList()))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
            if (restantes > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'Se muestran las primeras ${muestra.length} filas. El archivo incluye $restantes más.',
                    style: tema.textTheme.bodySmall),
              ),
            if (columnasAdicionales.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'El archivo además incluye: ${columnasAdicionales.join(', ')}.',
                    style: tema.textTheme.bodySmall),
              ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('previa-cancelar'),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('previa-descargar'),
                onPressed: totalRegistros == 0
                    ? null
                    : () => Navigator.pop(context, true),
                icon: Icon(iconoConfirmar),
                label: Text(textoConfirmar),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
