import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/servicios/diccionario_ortografico.dart';

void main() {
  final diccionario = DiccionarioOrtografico([
    'de',
    'la',
    'también',
    'bicicleta',
    'canción',
    'robaron',
    'casa',
    'cama',
    'cara',
    'capa',
  ]);

  test('reconoce las palabras sin importar mayúsculas', () {
    expect(diccionario.contiene('Bicicleta'), isTrue);
    expect(diccionario.contiene('bisicleta'), isFalse);
    expect(diccionario.cantidad, 10);
  });

  test('sugiere primero la misma palabra con tilde', () {
    expect(diccionario.sugerencias('tambien'), ['también']);
    expect(diccionario.sugerencias('cancion'), ['canción']);
  });

  test('corrige una letra cambiada, invertida o faltante', () {
    expect(diccionario.sugerencias('bisicleta'), ['bicicleta']);
    expect(diccionario.sugerencias('bicilceta'), ['bicicleta']);
    expect(diccionario.sugerencias('robaro'), ['robaron']);
  });

  test('entrega como máximo tres sugerencias, las más frecuentes primero', () {
    expect(diccionario.sugerencias('cata'), ['casa', 'cama', 'cara']);
  });

  test('conserva la mayúscula inicial de la palabra escrita', () {
    expect(diccionario.sugerencias('Cancion'), ['Canción']);
  });

  test('sin parecidas no inventa sugerencias', () {
    expect(diccionario.sugerencias('xyzw'), isEmpty);
  });

  test('quitar tildes deja la palabra base', () {
    expect(quitarTildes('canción pingüino'), 'cancion pinguino');
  });
}
