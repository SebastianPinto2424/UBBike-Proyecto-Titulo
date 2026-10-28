import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/utilidades/cercania_bicicletero.dart';

const _centroIdiomas = BicicleteroApp(
  id: 'centro-idiomas',
  nombre: 'Bicicletero cercano al Centro de Idiomas',
  ubicacion: 'Sector Centro de Idiomas',
  latitud: -36.82141385290648,
  longitud: -73.01254820745834,
  capacidad: 104,
  ocupados: 0,
  cuposDisponibles: 104,
  porcentajeUso: 0,
);

const _face = BicicleteroApp(
  id: 'face',
  nombre: 'Bicicletero cercano a la FACE',
  ubicacion: 'Sector FACE',
  latitud: -36.822041412853984,
  longitud: -73.01066005340653,
  capacidad: 120,
  ocupados: 0,
  cuposDisponibles: 120,
  porcentajeUso: 0,
);

void main() {
  group('bicicleteroMasCercano', () {
    test('sugiere el bicicletero cuando el usuario esta parado justo en el',
        () {
      final sugerencia = bicicleteroMasCercano(
        bicicleteros: [_centroIdiomas, _face],
        latitudUsuario: _centroIdiomas.latitud!,
        longitudUsuario: _centroIdiomas.longitud!,
      );

      expect(sugerencia, isNotNull);
      expect(sugerencia!.bicicletero.id, _centroIdiomas.id);
      expect(sugerencia.distanciaMetros, lessThan(5));
    });

    test('elige el mas cercano entre dos opciones dentro del radio', () {
      final sugerencia = bicicleteroMasCercano(
        bicicleteros: [_centroIdiomas, _face],
        latitudUsuario: -36.82190,
        longitudUsuario: -73.01100,
      );

      expect(sugerencia, isNotNull);
      expect(sugerencia!.bicicletero.id, _face.id);
    });

    test('no sugiere nada si el usuario esta lejos de ambos', () {
      final sugerencia = bicicleteroMasCercano(
        bicicleteros: [_centroIdiomas, _face],
        latitudUsuario: -36.8270,
        longitudUsuario: -73.0503,
      );

      expect(sugerencia, isNull);
    });

    test('ignora bicicleteros sin cupos aunque esten mas cerca', () {
      const faceSinCupos = BicicleteroApp(
        id: 'face',
        nombre: 'Bicicletero cercano a la FACE',
        ubicacion: 'Sector FACE',
        latitud: -36.822041412853984,
        longitud: -73.01066005340653,
        capacidad: 120,
        ocupados: 120,
        cuposDisponibles: 0,
        porcentajeUso: 100,
      );

      final sugerencia = bicicleteroMasCercano(
        bicicleteros: [_centroIdiomas, faceSinCupos],
        latitudUsuario: faceSinCupos.latitud!,
        longitudUsuario: faceSinCupos.longitud!,
      );

      expect(sugerencia, isNull);
    });

    test('ignora bicicleteros sin coordenadas cargadas', () {
      const sinCoordenadas = BicicleteroApp(
        id: 'sin-coordenadas',
        nombre: 'Bicicletero sin coordenadas',
        ubicacion: 'Sector desconocido',
        capacidad: 50,
        ocupados: 0,
        cuposDisponibles: 50,
        porcentajeUso: 0,
      );

      final sugerencia = bicicleteroMasCercano(
        bicicleteros: [sinCoordenadas],
        latitudUsuario: -36.8214,
        longitudUsuario: -73.0125,
      );

      expect(sugerencia, isNull);
    });
  });
}
