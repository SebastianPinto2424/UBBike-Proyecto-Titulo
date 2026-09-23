import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';

String _nombreSinExtension(String nombreArchivo) {
  final punto = nombreArchivo.lastIndexOf('.');
  return punto <= 0 ? nombreArchivo : nombreArchivo.substring(0, punto);
}

String _extension(String nombreArchivo, String porDefecto) {
  final punto = nombreArchivo.lastIndexOf('.');
  return punto <= 0 || punto == nombreArchivo.length - 1
      ? porDefecto
      : nombreArchivo.substring(punto + 1);
}

Future<bool> _guardarConDialogo({
  required String nombreArchivo,
  required Uint8List contenido,
  required String tipoMime,
  required String extensionPorDefecto,
}) async {
  final ruta = await FileSaver.instance.saveAs(
    name: _nombreSinExtension(nombreArchivo),
    bytes: contenido,
    fileExtension: _extension(nombreArchivo, extensionPorDefecto),
    mimeType: MimeType.custom,
    customMimeType: tipoMime,
  );

  return ruta != null;
}

Future<String> descargarReporteTexto({
  required String nombreArchivo,
  required String contenido,
  String tipoMime = 'text/plain;charset=utf-8',
}) async {
  try {
    final guardado = await _guardarConDialogo(
      nombreArchivo: nombreArchivo,
      contenido: Uint8List.fromList(utf8.encode(contenido)),
      tipoMime: tipoMime,
      extensionPorDefecto: 'txt',
    );

    if (guardado) {
      return 'Reporte descargado';
    }

    return 'Descarga cancelada';
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: contenido));
    return 'Reporte copiado al portapapeles';
  }
}

Future<bool> descargarReporteBytes({
  required String nombreArchivo,
  required Uint8List contenido,
  String tipoMime = 'application/octet-stream',
}) async {
  try {
    return await _guardarConDialogo(
      nombreArchivo: nombreArchivo,
      contenido: contenido,
      tipoMime: tipoMime,
      extensionPorDefecto: 'bin',
    );
  } catch (_) {
    return false;
  }
}
