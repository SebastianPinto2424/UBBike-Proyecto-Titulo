final RegExp _tieneLetra = RegExp(r'[a-zA-ZÀ-ÿ]');

String? validarNombreBicicletero(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa un nombre.';
  }
  if (texto.length < 3) {
    return 'Debe tener al menos 3 caracteres.';
  }
  if (texto.length > 120) {
    return 'Máximo 120 caracteres.';
  }
  if (!_tieneLetra.hasMatch(texto)) {
    return 'El nombre debe incluir texto, no solo símbolos.';
  }
  return null;
}

String? validarUbicacionBicicletero(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa la ubicación.';
  }
  if (texto.length < 3) {
    return 'Debe tener al menos 3 caracteres.';
  }
  if (texto.length > 255) {
    return 'Máximo 255 caracteres.';
  }
  return null;
}

String? validarCapacidadBicicletero(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa la capacidad.';
  }
  final numero = int.tryParse(texto);
  if (numero == null) {
    return 'Ingresa un número entero.';
  }
  if (numero < 1) {
    return 'Debe ser al menos 1.';
  }
  if (numero > 1000) {
    return 'Máximo 1000.';
  }
  return null;
}

String? validarLatitudBicicletero(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return null;
  }
  final numero = double.tryParse(texto.replaceAll(',', '.'));
  if (numero == null || !numero.isFinite) {
    return 'Ingresa un número válido.';
  }
  if (numero < -90 || numero > 90) {
    return 'Debe estar entre -90 y 90.';
  }
  return null;
}

String? validarLongitudBicicletero(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return null;
  }
  final numero = double.tryParse(texto.replaceAll(',', '.'));
  if (numero == null || !numero.isFinite) {
    return 'Ingresa un número válido.';
  }
  if (numero < -180 || numero > 180) {
    return 'Debe estar entre -180 y 180.';
  }
  return null;
}
