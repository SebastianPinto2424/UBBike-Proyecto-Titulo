import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class UbicacionServicio {
  const UbicacionServicio();

  Future<Position?> obtenerPosicionActual({
    LocationAccuracy precision = LocationAccuracy.medium,
    Duration limite = const Duration(seconds: 6),
  }) async {
    try {
      if (!await _ubicacionDisponible()) {
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

  Stream<Position> afinarPosicion({
    double precisionObjetivo = 10,
    Duration limite = const Duration(seconds: 15),
    Duration antiguedadMaxima = const Duration(minutes: 2),
  }) async* {
    try {
      if (!await _ubicacionDisponible()) return;
    } catch (_) {
      return;
    }

    Position? mejor;
    try {
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima != null &&
          DateTime.now().difference(ultima.timestamp) <= antiguedadMaxima) {
        mejor = ultima;
      }
    } catch (_) {}
    if (mejor != null) {
      yield mejor;
      if (mejor.accuracy <= precisionObjetivo) return;
    }

    final fin = DateTime.now().add(limite);
    final lecturas = Geolocator.getPositionStream(
      locationSettings: _ajustesPrecisos(),
    ).timeout(limite, onTimeout: (lecturas) => lecturas.close());
    try {
      await for (final posicion in lecturas) {
        if (mejor == null || posicion.accuracy < mejor.accuracy) {
          mejor = posicion;
          yield posicion;
        }
        if (posicion.accuracy <= precisionObjetivo ||
            !DateTime.now().isBefore(fin)) {
          return;
        }
      }
    } catch (_) {}
  }

  Future<bool> _ubicacionDisponible() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    return permiso != LocationPermission.denied &&
        permiso != LocationPermission.deniedForever;
  }

  LocationSettings _ajustesPrecisos() => switch (defaultTargetPlatform) {
        TargetPlatform.android => AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 1),
          ),
        TargetPlatform.iOS || TargetPlatform.macOS => AppleSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
            pauseLocationUpdatesAutomatically: false,
          ),
        _ => const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
          ),
      };

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
