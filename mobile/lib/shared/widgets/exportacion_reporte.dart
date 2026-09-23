import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/historial/application/movimientos_vm.dart';
import 'package:ubbike/shared/widgets/vista_previa_reporte.dart';
import 'package:ubbike/features/historial/presentation/widgets_movimientos.dart';
import 'package:ubbike/shared/utils/utiles_comun.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/servicios/descarga_reporte.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';

typedef FiltrosReporte = ({
  String? filtro,
  String? periodo,
  DateTime? desde,
  DateTime? hasta,
  String? tipo,
  String? estado,
  String? bicicleteroId,
  String? guardiaId,
  String? origen,
});

const encabezadosReporte = <String>[
  'Tipo',
  'Estado',
  'Fecha',
  'Hora',
  'Usuario',
  'Correo',
  'RUT',
  'Bicicleta',
  'Detalle bicicleta',
  'N° de serie',
  'Bicicletero',
  'Guardia',
  'Correo guardia',
  'Método',
];

const columnasSoloExcel = <String>[
  'Rol',
  'Correo verificado',
  'Cuenta activa',
  'Fecha de registro del usuario',
  'Ubicación del bicicletero',
];

String _detalleBicicleta(MovimientoApp m) {
  final partes = [
    m.bicicletaMarca,
    m.bicicletaModelo,
    m.bicicletaColor,
    if (m.bicicletaAro != null && m.bicicletaAro!.trim().isNotEmpty)
      'aro ${m.bicicletaAro}',
  ].whereType<String>().where((parte) => parte.trim().isNotEmpty);

  return partes.isEmpty ? '-' : partes.join(' · ');
}

List<String> filaReporte(MovimientoApp m) => [
      m.tipo == 'INGRESO' ? 'Ingreso' : 'Retiro',
      m.estado == 'CONFIRMADO' ? 'Confirmado' : 'Denegado',
      formatearFecha(m.creadoEn),
      formatearHora(m.creadoEn),
      m.usuarioNombre,
      m.usuarioCorreo,
      m.usuarioRut ?? 'Sin RUT',
      m.bicicletaDescripcion,
      _detalleBicicleta(m),
      m.bicicletaNumeroSerie ?? '-',
      m.bicicleteroNombre,
      m.guardiaNombre,
      m.guardiaCorreo ?? '-',
      etiquetaOrigenMovimientoFiltro(m.origen),
    ];

const limiteReporte = 100000;

final _anchosColumnasReporte = <int, pw.TableColumnWidth>{
  0: const pw.FlexColumnWidth(0.9),
  1: const pw.FlexColumnWidth(1.5),
  2: const pw.FlexColumnWidth(1.5),
  3: const pw.FlexColumnWidth(0.8),
  4: const pw.FlexColumnWidth(2.4),
  5: const pw.FlexColumnWidth(3.2),
  6: const pw.FlexColumnWidth(1.7),
  7: const pw.FlexColumnWidth(1.9),
  8: const pw.FlexColumnWidth(2.2),
  9: const pw.FlexColumnWidth(1.4),
  10: const pw.FlexColumnWidth(2.2),
  11: const pw.FlexColumnWidth(2.2),
  12: const pw.FlexColumnWidth(2.8),
  13: const pw.FlexColumnWidth(1.1),
};

class ExportadorReporte {
  const ExportadorReporte(this.ref);

  final WidgetRef ref;

  Future<List<MovimientoApp>?> _obtener(
      BuildContext context, FiltrosReporte filtros) async {
    try {
      return await ref.read(movimientosCentralVmProvider).listar(
            filtro: filtros.filtro,
            periodo: filtros.periodo,
            desde: filtros.desde,
            hasta: filtros.hasta,
            tipo: filtros.tipo,
            estado: filtros.estado,
            bicicleteroId: filtros.bicicleteroId,
            guardiaId: filtros.guardiaId,
            origen: filtros.origen,
            limite: limiteReporte,
          );
    } on ExcepcionApi catch (error) {
      if (context.mounted) context.mostrarError(error.mensaje);
      return null;
    } catch (_) {
      if (context.mounted) {
        context.mostrarError(
            'No se pudo preparar el reporte. Revisa tu conexión.');
      }
      return null;
    }
  }

  Future<bool> exportar({
    required BuildContext context,
    required String formato,
    required FiltrosReporte filtros,
    required String resumenFiltros,
  }) async {
    final movimientos = await _obtener(context, filtros);
    if (movimientos == null || !context.mounted) return false;

    final esExcel = formato == 'EXCEL';
    final confirmado = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (_) => VistaPreviaReporte(
        formato: esExcel ? 'Excel' : 'PDF',
        encabezados: encabezadosReporte,
        filas: movimientos.map(filaReporte).toList(),
        totalRegistros: movimientos.length,
        resumenFiltros: resumenFiltros,
        columnasAdicionales: esExcel ? columnasSoloExcel : const [],
      ),
    );

    if (confirmado != true || !context.mounted) return false;

    return esExcel
        ? _descargarExcel(context, filtros)
        : _descargarPdf(context, movimientos, resumenFiltros);
  }

  Future<bool> _descargarExcel(
      BuildContext context, FiltrosReporte filtros) async {
    try {
      final excel = await ref.read(movimientosCentralVmProvider).exportarExcel(
            filtro: filtros.filtro,
            periodo: filtros.periodo,
            desde: filtros.desde,
            hasta: filtros.hasta,
            tipo: filtros.tipo,
            estado: filtros.estado,
            bicicleteroId: filtros.bicicleteroId,
            guardiaId: filtros.guardiaId,
            origen: filtros.origen,
          );

      final descargado = await descargarReporteBytes(
        nombreArchivo:
            'historial-ubbike-${DateTime.now().millisecondsSinceEpoch}.xlsx',
        contenido: excel,
        tipoMime:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (context.mounted) {
        context.mostrarExito(
            descargado ? 'Reporte descargado' : 'Descarga cancelada');
      }
      return descargado;
    } on ExcepcionApi catch (error) {
      if (context.mounted) context.mostrarError(error.mensaje);
      return false;
    } catch (_) {
      if (context.mounted) {
        context.mostrarError('No se pudo exportar. Revisa tu conexión.');
      }
      return false;
    }
  }

  Future<bool> _descargarPdf(BuildContext context,
      List<MovimientoApp> movimientos, String resumenFiltros) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(18),
          build: (contexto) => [
            pw.Header(
                level: 0, child: pw.Text('Reporte de movimientos UBBike')),
            pw.Text('Filtros: $resumenFiltros'),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              context: contexto,
              headerStyle:
                  pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 6.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.5),
              columnWidths: _anchosColumnasReporte,
              data: <List<String>>[
                encabezadosReporte,
                ...movimientos.map(filaReporte),
              ],
            ),
          ],
        ),
      );

      final descargado = await descargarReporteBytes(
        nombreArchivo:
            'historial-ubbike-${DateTime.now().millisecondsSinceEpoch}.pdf',
        contenido: await pdf.save(),
        tipoMime: 'application/pdf',
      );

      if (context.mounted) {
        context.mostrarExito(
            descargado ? 'Reporte descargado' : 'Descarga cancelada');
      }
      return descargado;
    } catch (_) {
      if (context.mounted) {
        context.mostrarError('No se pudo exportar. Revisa tu conexión.');
      }
      return false;
    }
  }
}

class PanelExportarReporte extends StatelessWidget {
  const PanelExportarReporte({
    super.key,
    required this.exportando,
    required this.expandido,
    required this.formatoSeleccionado,
    required this.onToggle,
    required this.onFormato,
    required this.onDescargar,
  });

  final bool exportando;
  final bool expandido;
  final String? formatoSeleccionado;
  final VoidCallback onToggle;
  final ValueChanged<String?> onFormato;
  final VoidCallback onDescargar;

  @override
  Widget build(BuildContext context) {
    final etiquetaFormato = switch (formatoSeleccionado) {
      'EXCEL' => 'Excel',
      'PDF' => 'PDF',
      _ => 'Excel o PDF',
    };

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: exportando ? null : onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  if (exportando) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ColoresUbb.azulApp,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exportando ? 'Exportando' : 'Exportar',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: ColoresUbb.azulNoche,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Usa los filtros actuales',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: ColoresUbb.textoSecundario,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    etiquetaFormato,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColoresUbb.azulApp,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expandido
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: ColoresUbb.azulApp,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: expandido
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _OpcionFormatoExportacion(
                    titulo: 'Excel',
                    detalle: 'Archivo editable con los movimientos filtrados.',
                    seleccionado: formatoSeleccionado == 'EXCEL',
                    onChanged: exportando
                        ? null
                        : (activo) => onFormato(activo ? 'EXCEL' : null),
                  ),
                  const SizedBox(height: 10),
                  _OpcionFormatoExportacion(
                    titulo: 'PDF',
                    detalle: 'Reporte con formato, listo para imprimir.',
                    seleccionado: formatoSeleccionado == 'PDF',
                    onChanged: exportando
                        ? null
                        : (activo) => onFormato(activo ? 'PDF' : null),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: formatoSeleccionado == null || exportando
                        ? null
                        : onDescargar,
                    child: Text(exportando ? 'Descargando...' : 'Descargar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpcionFormatoExportacion extends StatelessWidget {
  const _OpcionFormatoExportacion({
    required this.titulo,
    required this.detalle,
    required this.seleccionado,
    required this.onChanged,
  });

  final String titulo;
  final String detalle;
  final bool seleccionado;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!seleccionado),
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionado
              ? ColoresUbb.azulApp.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: seleccionado ? ColoresUbb.azulApp : ColoresUbb.borde,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ColoresUbb.azulNoche,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColoresUbb.textoSecundario,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch.adaptive(
              value: seleccionado,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: ColoresUbb.azulApp,
            ),
          ],
        ),
      ),
    );
  }
}
