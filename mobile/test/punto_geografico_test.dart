import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/configuracion/configuracion_mapa.dart';
import 'package:ubbike/core/modelos/punto_geografico.dart';
import 'package:ubbike/shared/utils/opciones_bicicletero.dart';

void main() {
  test('normaliza coma decimal y mantiene latitud/longitud sin invertirlas',
      () {
    final punto = PuntoGeografico.desdeTexto(' -36,821728 ', '-73,011604')!;
    expect(punto.latitud, -36.821728);
    expect(punto.longitud, -73.011604);
    expect(punto.etiqueta, '-36.821728, -73.011604');
    expect(validarLatitudBicicletero('-36,82'), isNull);
    expect(validarLongitudBicicletero('-73,01'), isNull);
  });
  test('coordenadas ausentes no se convierten al centro del campus ni a cero',
      () {
    expect(PuntoGeografico.desdeTexto('', ''), isNull);
    expect(PuntoGeografico.desdeTexto('-36', ''), isNull);
    expect(PuntoGeografico.desdeTexto('', '-73'), isNull);
    expect(PuntoGeografico.desdeTexto('0', '0')!.esValido, isTrue);
  });
  for (final invalido in ['NaN', 'Infinity', '-Infinity', 'texto']) {
    test('rechaza $invalido en ambas coordenadas', () {
      expect(PuntoGeografico.desdeTexto(invalido, '0'), isNull);
      expect(PuntoGeografico.desdeTexto('0', invalido), isNull);
      expect(validarLatitudBicicletero(invalido), isNotNull);
      expect(validarLongitudBicicletero(invalido), isNotNull);
    });
  }
  test('valida rangos geográficos y configuración de encuadre', () {
    expect(PuntoGeografico.desdeTexto('90.01', '0'), isNull);
    expect(PuntoGeografico.desdeTexto('0', '-180.01'), isNull);
    expect(PuntoGeografico.desdeTexto('-90', '180')!.esValido, isTrue);
    expect(ConfiguracionMapa.centroCampus.esValido, isTrue);
    expect(ConfiguracionMapa.urlTiles, startsWith('https://'));
    expect(ConfiguracionMapa.urlTiles, contains('{z}/{x}/{y}'));
  });
}
