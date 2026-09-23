import 'package:geolocator/geolocator.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

const distanciaMaximaSugerenciaMetros = 150.0;

class SugerenciaBicicletero {
  const SugerenciaBicicletero({
    required this.bicicletero,
    required this.distanciaMetros,
  });

  final BicicleteroApp bicicletero;
  final double distanciaMetros;
}

SugerenciaBicicletero? bicicleteroMasCercano({
  required List<BicicleteroApp> bicicleteros,
  required double latitudUsuario,
  required double longitudUsuario,
  double distanciaMaximaMetros = distanciaMaximaSugerenciaMetros,
}) {
  SugerenciaBicicletero? masCercano;

  for (final bicicletero in bicicleteros) {
    final latitud = bicicletero.latitud;
    final longitud = bicicletero.longitud;
    if (latitud == null ||
        longitud == null ||
        bicicletero.cuposDisponibles <= 0) {
      continue;
    }

    final distancia = Geolocator.distanceBetween(
      latitudUsuario,
      longitudUsuario,
      latitud,
      longitud,
    );

    if (distancia > distanciaMaximaMetros) {
      continue;
    }

    if (masCercano == null || distancia < masCercano.distanciaMetros) {
      masCercano = SugerenciaBicicletero(
        bicicletero: bicicletero,
        distanciaMetros: distancia,
      );
    }
  }

  return masCercano;
}
