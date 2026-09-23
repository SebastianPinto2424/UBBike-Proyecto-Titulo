import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ubbike/shared/servicios/ubicacion_servicio.dart';

class _Plataforma extends GeolocatorPlatform {
  bool habilitado = true;
  LocationPermission permiso = LocationPermission.whileInUse;
  LocationPermission respuesta = LocationPermission.whileInUse;
  int solicitudes = 0;
  int posiciones = 0;
  LocationSettings? ajustes;
  Object? fallo;

  @override
  Future<bool> isLocationServiceEnabled() async => habilitado;
  @override
  Future<LocationPermission> checkPermission() async => permiso;
  @override
  Future<LocationPermission> requestPermission() async {
    solicitudes++;
    return respuesta;
  }

  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    posiciones++;
    ajustes = locationSettings;
    if (fallo != null) throw fallo!;
    return Position(
        latitude: -36.821,
        longitude: -73.011,
        timestamp: DateTime.now(),
        accuracy: 8,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0);
  }
}

void main() {
  late _Plataforma plataforma;
  const servicio = UbicacionServicio();
  setUp(() {
    final anterior = GeolocatorPlatform.instance;
    plataforma = _Plataforma();
    GeolocatorPlatform.instance = plataforma;
    addTearDown(() => GeolocatorPlatform.instance = anterior);
  });

  test('conserva precisión y plazo anteriores para la cercanía en QR',
      () async {
    expect(await servicio.obtenerPosicionActual(), isNotNull);
    expect(plataforma.ajustes!.accuracy, LocationAccuracy.medium);
    expect(plataforma.ajustes!.timeLimit, const Duration(seconds: 6));
    expect(plataforma.solicitudes, 0);
  });
  test('el mapa puede solicitar alta precisión y un plazo mayor', () async {
    final posicion = await servicio.obtenerPosicionActual(
        precision: LocationAccuracy.high, limite: const Duration(seconds: 20));
    expect(posicion!.latitude, -36.821);
    expect(plataforma.ajustes!.accuracy, LocationAccuracy.high);
    expect(plataforma.ajustes!.timeLimit, const Duration(seconds: 20));
  });
  test('localización apagada no solicita permisos ni coordenadas', () async {
    plataforma.habilitado = false;
    expect(await servicio.obtenerPosicionActual(), isNull);
    expect(plataforma.solicitudes, 0);
    expect(plataforma.posiciones, 0);
  });
  test('solicita el permiso y obtiene posición si se concede', () async {
    plataforma.permiso = LocationPermission.denied;
    expect(await servicio.obtenerPosicionActual(), isNotNull);
    expect(plataforma.solicitudes, 1);
    expect(plataforma.posiciones, 1);
  });
  test('permiso denegado no obtiene coordenadas', () async {
    plataforma.permiso = LocationPermission.denied;
    plataforma.respuesta = LocationPermission.denied;
    expect(await servicio.obtenerPosicionActual(), isNull);
    expect(plataforma.solicitudes, 1);
    expect(plataforma.posiciones, 0);
  });
  test('permiso bloqueado permanentemente no repite el diálogo', () async {
    plataforma.permiso = LocationPermission.deniedForever;
    expect(await servicio.obtenerPosicionActual(), isNull);
    expect(plataforma.solicitudes, 0);
    expect(plataforma.posiciones, 0);
  });
  test('timeout no produce una posición inventada ni propaga el error',
      () async {
    plataforma.fallo = TimeoutException('Sin señal');
    expect(await servicio.obtenerPosicionActual(), isNull);
  });
}
