import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/shared/utilidades/limites_foto.dart';

Uint8List _bytes(List<int> cabecera, {int relleno = 16}) {
  return Uint8List.fromList([...cabecera, ...List<int>.filled(relleno, 0)]);
}

void main() {
  group('detectarMimeDesdeBytes', () {
    test('reconoce JPEG por su firma', () {
      expect(detectarMimeDesdeBytes(_bytes([0xFF, 0xD8, 0xFF])), 'image/jpeg');
    });

    test('reconoce PNG por su firma', () {
      expect(
        detectarMimeDesdeBytes(_bytes([0x89, 0x50, 0x4E, 0x47])),
        'image/png',
      );
    });

    test('reconoce WEBP por su firma', () {
      final webp = _bytes([
        0x52,
        0x49,
        0x46,
        0x46,
        0x00,
        0x00,
        0x00,
        0x00,
        0x57,
        0x45,
        0x42,
        0x50,
      ]);
      expect(detectarMimeDesdeBytes(webp), 'image/webp');
    });

    test('un formato desconocido no se hace pasar por imagen', () {
      final pdf = _bytes([0x25, 0x50, 0x44, 0x46]);
      final mime = detectarMimeDesdeBytes(pdf);

      expect(
        mimesFotoPermitidos.contains(mime),
        isFalse,
        reason: 'si el fallback devolviera image/jpeg, un archivo que no es '
            'imagen pasaria la validacion del cliente y solo lo rechazaria '
            'el servidor',
      );
    });

    test('un ejecutable tampoco pasa la validacion', () {
      final exe = _bytes([0x4D, 0x5A]);
      expect(
          mimesFotoPermitidos.contains(detectarMimeDesdeBytes(exe)), isFalse);
    });

    test('bytes vacios no pasan la validacion', () {
      expect(
        mimesFotoPermitidos.contains(detectarMimeDesdeBytes(Uint8List(0))),
        isFalse,
      );
    });
  });

  group('mimesFotoPermitidos', () {
    test('solo acepta formatos de imagen', () {
      expect(mimesFotoPermitidos, {
        'image/jpeg',
        'image/jpg',
        'image/png',
        'image/webp',
      });
    });
  });

  group('prepararFoto', () {
    test('convierte una imagen válida en data URL con su tipo real', () {
      final foto = prepararFoto(_bytes([0x89, 0x50, 0x4E, 0x47]));

      expect(foto.error, isNull);
      expect(foto.dataUrl, startsWith('data:image/png;base64,'));
    });

    test('rechaza un archivo que no es JPG, PNG ni WEBP', () {
      final foto = prepararFoto(_bytes([0x47, 0x49, 0x46, 0x38]));

      expect(foto.dataUrl, isNull);
      expect(foto.error, 'La foto debe ser JPG, PNG o WEBP.');
    });

    test('respeta un límite de bytes más estricto', () {
      final foto = prepararFoto(
        _bytes([0xFF, 0xD8, 0xFF], relleno: 100),
        maximoBytes: 50,
      );

      expect(foto.dataUrl, isNull);
      expect(foto.error, contains('muy pesada'));
    });
  });
}
