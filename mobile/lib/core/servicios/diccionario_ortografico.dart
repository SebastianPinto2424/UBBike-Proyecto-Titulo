const _tildes = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};

final _alfabeto = 'abcdefghijklmnñopqrstuvwxyzáéíóúü'.split('');

String quitarTildes(String palabra) =>
    palabra.split('').map((letra) => _tildes[letra] ?? letra).join();

class DiccionarioOrtografico {
  DiccionarioOrtografico(Iterable<String> palabrasPorFrecuencia) {
    for (final palabra in palabrasPorFrecuencia) {
      final minuscula = palabra.trim().toLowerCase();
      if (minuscula.isEmpty || _posiciones.containsKey(minuscula)) continue;
      _posiciones[minuscula] = _posiciones.length;
      _porForma.putIfAbsent(quitarTildes(minuscula), () => []).add(minuscula);
    }
  }

  final _posiciones = <String, int>{};
  final _porForma = <String, List<String>>{};

  int get cantidad => _posiciones.length;

  bool contiene(String palabra) =>
      _posiciones.containsKey(palabra.toLowerCase());

  List<String> sugerencias(String palabra, {int maximo = 3}) {
    final minuscula = palabra.toLowerCase();
    final porTilde = _porForma[quitarTildes(minuscula)] ?? const <String>[];
    final porEdicion = _ediciones(minuscula)
        .where(_posiciones.containsKey)
        .where((candidata) => !porTilde.contains(candidata))
        .toList()
      ..sort((a, b) => _posiciones[a]!.compareTo(_posiciones[b]!));

    return [...porTilde, ...porEdicion]
        .where((candidata) => candidata != minuscula)
        .take(maximo)
        .map((candidata) => _conMayusculaComo(palabra, candidata))
        .toList();
  }

  Set<String> _ediciones(String palabra) {
    final ediciones = <String>{};
    for (var i = 0; i <= palabra.length; i++) {
      final inicio = palabra.substring(0, i);
      final resto = palabra.substring(i);
      for (final letra in _alfabeto) {
        ediciones.add('$inicio$letra$resto');
      }
      if (resto.isEmpty) continue;
      ediciones.add('$inicio${resto.substring(1)}');
      for (final letra in _alfabeto) {
        ediciones.add('$inicio$letra${resto.substring(1)}');
      }
      if (resto.length > 1) {
        ediciones.add('$inicio${resto[1]}${resto[0]}${resto.substring(2)}');
      }
    }
    return ediciones;
  }

  String _conMayusculaComo(String original, String sugerencia) {
    final empiezaConMayuscula =
        original.isNotEmpty && original[0] != original[0].toLowerCase();
    return empiezaConMayuscula
        ? '${sugerencia[0].toUpperCase()}${sugerencia.substring(1)}'
        : sugerencia;
  }
}
