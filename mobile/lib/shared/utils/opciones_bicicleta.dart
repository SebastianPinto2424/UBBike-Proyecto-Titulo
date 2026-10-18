const List<String> arosBicicleta = [
  '29',
  '28',
  '27.5',
  '27',
  '26',
  '24',
  '22',
  '20',
  '18',
  '17',
  '16',
  '14',
  '12',
];

const List<String> coloresBicicleta = [
  'Amarillo',
  'Azul',
  'Azul marino',
  'Beige',
  'Blanco',
  'Burdeo',
  'Café',
  'Calipso',
  'Celeste',
  'Champaña',
  'Cian',
  'Cobre',
  'Crema',
  'Dorado',
  'Fucsia',
  'Grafito',
  'Gris',
  'Lila',
  'Magenta',
  'Multicolor',
  'Morado',
  'Mostaza',
  'Naranjo',
  'Negro',
  'Plateado',
  'Rojo',
  'Rosado',
  'Turquesa',
  'Verde',
  'Verde agua',
  'Verde oliva',
  'Violeta',
];

const Map<String, String> _aliasArosBicicleta = {
  '28 1/2': '28',
  '28 x 1 1/2': '28',
  '28 x 1 1/2 (iso 635)': '28',
  '27 (iso 630)': '27',
  '29 / 700c / 28 (iso 622)': '29',
  '700c': '29',
  '28': '28',
  '26 1 1/4': '26',
  '26 x 1 1/4': '26',
  '26 x 1 1/4 (iso 597)': '26',
  '26 1 3/8': '26',
  '26 x 1 3/8': '26',
  '26 x 1 3/8 / 650a (iso 590)': '26',
  '650a': '26',
  '27.5 / 650b (iso 584)': '27.5',
  '650b': '27.5',
  '650c': '27',
  '650c (iso 571)': '27',
  '26 (iso 559)': '26',
  '24 1 1/4': '24',
  '24 x 1 1/4': '24',
  '24 x 1 1/4 (iso 547)': '24',
  '24 1 1/8': '24',
  '24 x 1 1/8': '24',
  '24 x 1 1/8 (iso 540)': '24',
  '24 1': '24',
  '24 x 1': '24',
  '24 x 1 (iso 520)': '24',
  '24 (iso 507)': '24',
  '22 (iso 501)': '22',
  '20 1 1/8': '20',
  '20 x 1 1/8': '20',
  '20 x 1 1/8 (iso 451)': '20',
  '20 (iso 406)': '20',
  '18 (iso 355)': '18',
  '17 (iso 369)': '17',
  '16 1 3/8': '16',
  '16 x 1 3/8': '16',
  '16 x 1 3/8 (iso 349)': '16',
  '16 (iso 305)': '16',
  '14 (iso 254)': '14',
  '12 (iso 203)': '12',
  '12.5': '12',
};

const Map<String, String> _aliasColoresBicicleta = {
  'amarillo': 'Amarillo',
  'amarilla': 'Amarillo',
  'azul': 'Azul',
  'marino': 'Azul marino',
  'navy': 'Azul marino',
  'azul oscuro': 'Azul marino',
  'azul marino': 'Azul marino',
  'beige': 'Beige',
  'blanco': 'Blanco',
  'blanca': 'Blanco',
  'burdeo': 'Burdeo',
  'borgona': 'Burdeo',
  'borgoña': 'Burdeo',
  'vino': 'Burdeo',
  'cafe': 'Café',
  'marron': 'Café',
  'marrón': 'Café',
  'calipso': 'Calipso',
  'aqua': 'Calipso',
  'celeste': 'Celeste',
  'champana': 'Champaña',
  'champaña': 'Champaña',
  'champagne': 'Champaña',
  'cian': 'Cian',
  'cyan': 'Cian',
  'cobre': 'Cobre',
  'bronce': 'Cobre',
  'crema': 'Crema',
  'dorado': 'Dorado',
  'dorada': 'Dorado',
  'fucsia': 'Fucsia',
  'grafito': 'Grafito',
  'gris oscuro': 'Grafito',
  'gris': 'Gris',
  'plomo': 'Gris',
  'lila': 'Lila',
  'magenta': 'Magenta',
  'multicolor': 'Multicolor',
  'morado': 'Morado',
  'purpura': 'Morado',
  'púrpura': 'Morado',
  'mostaza': 'Mostaza',
  'naranjo': 'Naranjo',
  'naranja': 'Naranjo',
  'negro': 'Negro',
  'negra': 'Negro',
  'plateado': 'Plateado',
  'plateada': 'Plateado',
  'plata': 'Plateado',
  'rojo': 'Rojo',
  'roja': 'Rojo',
  'rosado': 'Rosado',
  'rosada': 'Rosado',
  'rosa': 'Rosado',
  'turquesa': 'Turquesa',
  'verde': 'Verde',
  'verde claro': 'Verde agua',
  'verde agua': 'Verde agua',
  'verde militar': 'Verde oliva',
  'verde oliva': 'Verde oliva',
  'violeta': 'Violeta',
};

final _tieneLetra = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]');
final _tieneLetraONumero = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9]');
final _patronMarcaModelo = RegExp(r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9 .&-]+$');
final _patronNumeroSerie = RegExp(r'^[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*$');
final _separadorColores = RegExp(r'\s*(?:/|\+|,|&|\by\b|\be\b)\s*');

final Map<String, String> _arosPorClave = {
  for (final aro in arosBicicleta) _claveCatalogo(aro): aro,
  for (final entry in _aliasArosBicicleta.entries)
    _claveCatalogo(entry.key): entry.value,
};

final Map<String, String> _coloresPorClave = {
  for (final color in coloresBicicleta) _claveCatalogo(color): color,
  for (final entry in _aliasColoresBicicleta.entries)
    _claveCatalogo(entry.key): entry.value,
};

String _claveCatalogo(String valor) {
  var texto = valor.trim().toLowerCase();
  const reemplazos = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  for (final entry in reemplazos.entries) {
    texto = texto.replaceAll(entry.key, entry.value);
  }

  return texto
      .replaceAll(RegExp("[“”\"']"), '')
      .replaceAll(RegExp(r'[-–—]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? normalizarAroBicicleta(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return null;
  }
  return _arosPorClave[_claveCatalogo(texto)];
}

String? normalizarColorBicicleta(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return null;
  }

  final directo = _coloresPorClave[_claveCatalogo(texto)];
  if (directo != null) {
    return directo;
  }

  final partesTexto = texto
      .split(_separadorColores)
      .map((parte) => parte.trim())
      .where((parte) => parte.isNotEmpty)
      .toList();
  final partes = partesTexto
      .map((parte) => _coloresPorClave[_claveCatalogo(parte)])
      .toList();

  if (partes.length < 2 ||
      partes.length > 3 ||
      partes.any((parte) => parte == null)) {
    return null;
  }

  final unicos = partes.whereType<String>().toSet().toList();
  return unicos.length >= 2 ? unicos.join(' / ') : null;
}

List<String> sugerirColoresBicicleta(String valor) {
  final clave = _claveCatalogo(valor);
  if (clave.isEmpty) {
    return coloresBicicleta;
  }

  return coloresBicicleta.where((color) {
    final claveColor = _claveCatalogo(color);
    if (claveColor.contains(clave)) {
      return true;
    }

    return _aliasColoresBicicleta.entries.any(
      (entry) =>
          entry.value == color && _claveCatalogo(entry.key).contains(clave),
    );
  }).toList();
}

String? validarDescripcionBicicleta(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa una descripción.';
  }
  if (texto.length < 3) {
    return 'Debe tener al menos 3 caracteres.';
  }
  if (texto.length > 100) {
    return 'Máximo 100 caracteres.';
  }
  if (!_tieneLetra.hasMatch(texto)) {
    return 'La descripción debe incluir texto, no solo símbolos.';
  }
  return null;
}

String? validarMarcaBicicleta(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa la marca.';
  }
  if (texto.length < 2) {
    return 'Debe tener al menos 2 caracteres.';
  }
  if (texto.length > 40) {
    return 'Máximo 40 caracteres.';
  }
  if (!_patronMarcaModelo.hasMatch(texto)) {
    return 'Solo letras, números y los signos - . &';
  }
  if (!_tieneLetra.hasMatch(texto)) {
    return 'La marca debe incluir texto identificable.';
  }
  return null;
}

String? validarModeloBicicleta(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa el modelo.';
  }
  if (texto.length > 40) {
    return 'Máximo 40 caracteres.';
  }
  if (!_patronMarcaModelo.hasMatch(texto)) {
    return 'Solo letras, números y los signos - . &';
  }
  if (!_tieneLetraONumero.hasMatch(texto)) {
    return 'El modelo debe incluir texto o números.';
  }
  return null;
}

String? validarColorBicicleta(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa el color.';
  }
  if (texto.length > 60) {
    return 'Máximo 60 caracteres.';
  }
  if (normalizarColorBicicleta(texto) == null) {
    return 'Ingresa un color válido.';
  }
  return null;
}

String? validarNumeroSerieBicicleta(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa el número de serie.';
  }
  if (texto.length < 4) {
    return 'Debe tener al menos 4 caracteres.';
  }
  if (texto.length > 40) {
    return 'Máximo 40 caracteres.';
  }
  if (!_patronNumeroSerie.hasMatch(texto)) {
    return 'Usa letras, números y guion, sin espacios.';
  }
  return null;
}

String? validarAroBicicleta(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Selecciona el aro.';
  }
  if (normalizarAroBicicleta(texto) == null) {
    return 'Selecciona un aro válido.';
  }
  return null;
}
