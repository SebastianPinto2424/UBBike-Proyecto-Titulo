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

Future<bool> descargarReporteBytes({
  required String nombreArchivo,
  required Uint8List contenido,
  String tipoMime = 'application/octet-stream',
}) async {
  try {
    final ruta = await FileSaver.instance.saveAs(
      name: _nombreSinExtension(nombreArchivo),
      bytes: contenido,
      fileExtension: _extension(nombreArchivo, 'bin'),
      mimeType: MimeType.custom,
      customMimeType: tipoMime,
    );
    return ruta != null;
  } catch (_) {
    return false;
  }
}
