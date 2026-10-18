import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> compartirReporteBytes({
  required String nombreArchivo,
  required Uint8List contenido,
  required String tipoMime,
  String? asunto,
  String? texto,
}) async {
  try {
    final archivo = XFile.fromData(
      contenido,
      mimeType: tipoMime,
      name: nombreArchivo,
    );

    final resultado = await SharePlus.instance.share(
      ShareParams(
        files: [archivo],
        fileNameOverrides: [nombreArchivo],
        subject: asunto,
        text: texto,
      ),
    );

    return resultado.status != ShareResultStatus.dismissed;
  } catch (_) {
    return false;
  }
}
