import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ubbike/core/configuracion/configuracion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';

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
      ? Image.memory(bytesFoto, fit: BoxFit.contain)
      : Image.network(
          resolverUrlFotoBicicleta(fotoReferencia),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.broken_image_outlined,
            color: ColoresUbb.textoSecundario,
            size: 64,
          ),
        );

  return showDialog<void>(
    context: context,
    builder: (context) {
      final size = MediaQuery.sizeOf(context);
      final ancho = (size.width - 32).clamp(280.0, 560.0);
      final alto = (ancho * 0.72).clamp(220.0, size.height * 0.68);

      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.white,
        child: Stack(
          children: [
            SizedBox(
              width: ancho,
              height: alto,
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(child: imagen),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    },
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
