import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void _descargarBlob(web.Blob blob, String nombreArchivo) {
  final url = web.URL.createObjectURL(blob);
  final ancla = web.HTMLAnchorElement()
    ..href = url
    ..download = nombreArchivo
    ..style.display = 'none';

  web.document.body!.append(ancla);
  ancla.click();
  ancla.remove();

  Future<void>.delayed(
    const Duration(seconds: 5),
    () => web.URL.revokeObjectURL(url),
  );
}

Future<String> descargarReporteTexto({
  required String nombreArchivo,
  required String contenido,
  String tipoMime = 'text/plain;charset=utf-8',
}) async {
  final blob = web.Blob(
    <web.BlobPart>[contenido.toJS].toJS,
    web.BlobPropertyBag(type: tipoMime),
  );

  _descargarBlob(blob, nombreArchivo);
  return 'Reporte descargado';
}

Future<bool> descargarReporteBytes({
  required String nombreArchivo,
  required Uint8List contenido,
  String tipoMime = 'application/octet-stream',
}) async {
  final blob = web.Blob(
    <web.BlobPart>[contenido.toJS].toJS,
    web.BlobPropertyBag(type: tipoMime),
  );

  _descargarBlob(blob, nombreArchivo);
  return true;
}
