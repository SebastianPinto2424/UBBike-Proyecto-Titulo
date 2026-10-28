import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ubbike/core/configuracion/configuracion_api.dart';
import 'package:ubbike/shared/widgets/visor_foto.dart';

Uint8List? decodificarFotoDataUrl(String? fotoDataUrl) {
  if (fotoDataUrl == null || !fotoDataUrl.startsWith('data:image')) {
    return null;
  }

  final partes = fotoDataUrl.split(',');
  if (partes.length < 2) {
    return null;
  }

  try {
    return base64Decode(partes.last);
  } on FormatException {
    return null;
  }
}

String resolverUrlFotoBicicleta(String fotoUrl) {
  if (fotoUrl.startsWith('data:image') ||
      fotoUrl.startsWith('http://') ||
      fotoUrl.startsWith('https://')) {
    return fotoUrl;
  }

  if (fotoUrl.startsWith('/')) {
    return '${ConfiguracionApi.baseUrl}$fotoUrl';
  }

  return fotoUrl;
}

Future<void> mostrarFotoBicicletaAmpliada(
  BuildContext context,
  String fotoReferencia,
) {
  final bytesFoto = decodificarFotoDataUrl(fotoReferencia);
  final imagen = bytesFoto != null
      ? Image.memory(
          bytesFoto,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        )
      : Image.network(
          resolverUrlFotoBicicleta(fotoReferencia),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          loadingBuilder: (_, hijo, progreso) => progreso == null
              ? hijo
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white70,
              size: 64,
            ),
          ),
        );

  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => VisorFoto(imagen: imagen),
    ),
  );
}

String formatearFecha(DateTime fecha) {
  final local = fecha.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final mes = local.month.toString().padLeft(2, '0');
  return '$dia/$mes/${local.year}';
}

String formatearHora(DateTime fecha) {
  final local = fecha.toLocal();
  final hora = local.hour.toString().padLeft(2, '0');
  final minuto = local.minute.toString().padLeft(2, '0');
  return '$hora:$minuto';
}
