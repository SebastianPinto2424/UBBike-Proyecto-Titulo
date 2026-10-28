import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ubbike/shared/utilidades/limites_foto.dart';
import 'package:ubbike/shared/widgets/pantalla_camara.dart';

class CapturaFotos {
  CapturaFotos({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<FotoPreparada?> elegir(
    BuildContext context,
    ImageSource fuente, {
    required int calidad,
    required double ladoMaximo,
    int? maximoBytes,
  }) async {
    if (fuente == ImageSource.camera) {
      final bytes = await tomarFotoEnApp(context);
      return bytes == null
          ? null
          : prepararFoto(bytes, maximoBytes: maximoBytes);
    }

    final imagen = await _picker.pickImage(
      source: fuente,
      imageQuality: calidad,
      maxWidth: ladoMaximo,
      maxHeight: ladoMaximo,
    );
    if (imagen == null) {
      return null;
    }
    return prepararFoto(await imagen.readAsBytes(), maximoBytes: maximoBytes);
  }

  Future<FotoPreparada?> recuperarPerdida({int? maximoBytes}) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    final respuesta = await _picker.retrieveLostData();
    if (respuesta.isEmpty) {
      return null;
    }
    final archivos = respuesta.files;
    final archivo = archivos != null && archivos.isNotEmpty
        ? archivos.first
        : respuesta.file;
    if (archivo == null) {
      return null;
    }
    return prepararFoto(await archivo.readAsBytes(), maximoBytes: maximoBytes);
  }
}
