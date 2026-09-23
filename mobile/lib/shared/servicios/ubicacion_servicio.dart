import 'package:geolocator/geolocator.dart';

class UbicacionServicio {
  const UbicacionServicio();

  Future<Position?> obtenerPosicionActual({
    LocationAccuracy precision = LocationAccuracy.medium,
    Duration limite = const Duration(seconds: 6),
  }) async {
    try {
      final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        return null;
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }

      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: precision,
          timeLimit: limite,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  double distanciaEnMetros({
    required double latitudOrigen,
    required double longitudOrigen,
    required double latitudDestino,
    required double longitudDestino,
  }) {
    return Geolocator.distanceBetween(
      latitudOrigen,
      longitudOrigen,
      latitudDestino,
      longitudDestino,
    );
  }
}
