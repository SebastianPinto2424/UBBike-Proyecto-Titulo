import 'dart:convert';
import 'dart:typed_data';

const int largoMaximoFotoDataUrl = 7000000;

const _mensajeFormato = 'La foto debe ser JPG, PNG o WEBP.';
const _mensajePeso = 'La foto es muy pesada. Elige una imagen más liviana.';

typedef FotoPreparada = ({String? dataUrl, String? error});

FotoPreparada prepararFoto(Uint8List bytes, {int? maximoBytes}) {
  final mime = detectarMimeDesdeBytes(bytes);
  if (!mimesFotoPermitidos.contains(mime)) {
    return (dataUrl: null, error: _mensajeFormato);
  }
  if (maximoBytes != null && bytes.length > maximoBytes) {
    return (dataUrl: null, error: _mensajePeso);
  }

  final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
  if (dataUrl.length > largoMaximoFotoDataUrl) {
    return (dataUrl: null, error: _mensajePeso);
  }
  return (dataUrl: dataUrl, error: null);
}

const Set<String> mimesFotoPermitidos = {
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
};

String detectarMimeDesdeBytes(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return '';
}
