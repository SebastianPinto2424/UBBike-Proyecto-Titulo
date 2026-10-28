import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:ubbike/features/historial/application/nombre_reporte.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/features/historial/application/movimientos_vm.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/servicios/compartir_reporte.dart';
import 'package:ubbike/shared/servicios/descarga_reporte.dart';
import 'package:ubbike/shared/utilidades/etiquetas_movimiento.dart';
import 'package:ubbike/shared/utilidades/utiles_comun.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/vista_previa_reporte.dart';

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

enum AccionReporte { descargar, compartir }

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
    AccionReporte accion = AccionReporte.descargar,
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
        textoConfirmar:
            accion == AccionReporte.compartir ? 'Compartir' : 'Descargar',
        iconoConfirmar: accion == AccionReporte.compartir
            ? Icons.ios_share
            : Icons.download_outlined,
      ),
    );

    if (confirmado != true || !context.mounted) return false;

    return esExcel
        ? _entregarExcel(context, filtros, accion)
        : _entregarPdf(context, movimientos, resumenFiltros, accion);
  }

  Future<bool> _entregar(
    BuildContext context, {
    required String nombreArchivo,
    required Uint8List contenido,
    required String tipoMime,
    required AccionReporte accion,
  }) async {
    if (accion == AccionReporte.compartir) {
      final compartido = await compartirReporteBytes(
        nombreArchivo: nombreArchivo,
        contenido: contenido,
        tipoMime: tipoMime,
        asunto: 'Reporte de movimientos UBBike',
        texto: 'Adjunto el reporte generado desde UBBike.',
      );

      if (context.mounted) {
        if (compartido) {
          context.mostrarExito('Reporte compartido');
        } else {
          context.mostrarError('No se pudo compartir el reporte');
        }
      }
      return compartido;
    }

    final descargado = await descargarReporteBytes(
      nombreArchivo: nombreArchivo,
      contenido: contenido,
      tipoMime: tipoMime,
    );

    if (context.mounted) {
      context.mostrarExito(
          descargado ? 'Reporte descargado' : 'Descarga cancelada');
    }
    return descargado;
  }

  Future<bool> _entregarExcel(BuildContext context, FiltrosReporte filtros,
      AccionReporte accion) async {
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

      if (!context.mounted) return false;

      return _entregar(
        context,
        nombreArchivo: nombreArchivoReporte(DateTime.now(), 'xlsx'),
        contenido: excel,
        tipoMime:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        accion: accion,
      );
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

  Future<bool> _entregarPdf(
      BuildContext context,
      List<MovimientoApp> movimientos,
      String resumenFiltros,
      AccionReporte accion) async {
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

      final contenido = await pdf.save();
      if (!context.mounted) return false;

      return _entregar(
        context,
        nombreArchivo: nombreArchivoReporte(DateTime.now(), 'pdf'),
        contenido: contenido,
        tipoMime: 'application/pdf',
        accion: accion,
      );
    } catch (_) {
      if (context.mounted) {
        context.mostrarError('No se pudo exportar. Revisa tu conexión.');
      }
      return false;
    }
  }
}
