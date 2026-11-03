import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ubbike/core/servicios/ubicacion_servicio.dart';

class _Plataforma extends GeolocatorPlatform {
  bool habilitado = true;
  LocationPermission permiso = LocationPermission.whileInUse;
  LocationPermission respuesta = LocationPermission.whileInUse;
  int solicitudes = 0;
  int posiciones = 0;
  LocationSettings? ajustes;
  Object? fallo;
  Position? ultima;
  Stream<Position> Function() lecturas = () => const Stream.empty();
  LocationSettings? ajustesLecturas;
  int seguimientos = 0;

  @override
  Future<Position?> getLastKnownPosition(
          {bool forceLocationManager = false}) async =>
      ultima;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    seguimientos++;
    ajustesLecturas = locationSettings;
    return lecturas();
  }

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

  group('afinar la posición', () {
    Position lectura(double precision, {DateTime? hora}) => Position(
        latitude: -36.821,
        longitude: -73.011,
        timestamp: hora ?? DateTime.now(),
        accuracy: precision,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0);

    Future<List<double>> precisiones(Stream<Position> posiciones) async =>
        [await for (final posicion in posiciones) posicion.accuracy];

    test(
        'entrega al instante la última posición reciente y luego solo '
        'lecturas más precisas hasta llegar a 10 m', () async {
      plataforma.ultima = lectura(60,
          hora: DateTime.now().subtract(const Duration(seconds: 30)));
      plataforma.lecturas = () => Stream.fromIterable(
          [lectura(40), lectura(70), lectura(9), lectura(5)]);

      expect(await precisiones(servicio.afinarPosicion()), [60, 40, 9]);
    });

    test('una última posición antigua no se muestra', () async {
      plataforma.ultima = lectura(5,
          hora: DateTime.now().subtract(const Duration(minutes: 10)));
      plataforma.lecturas = () => Stream.fromIterable([lectura(12)]);

      expect(await precisiones(servicio.afinarPosicion()), [12]);
    });

    test('si la última posición ya es precisa no enciende el GPS', () async {
      plataforma.ultima = lectura(6);

      expect(await precisiones(servicio.afinarPosicion()), [6]);
      expect(plataforma.seguimientos, 0);
    });

    test('pide máxima precisión y una lectura por segundo en Android',
        () async {
      plataforma.lecturas = () => Stream.fromIterable([lectura(4)]);

      await precisiones(servicio.afinarPosicion());

      final ajustes = plataforma.ajustesLecturas as AndroidSettings;
      expect(ajustes.accuracy, LocationAccuracy.best);
      expect(ajustes.intervalDuration, const Duration(seconds: 1));
      expect(ajustes.distanceFilter, 0);
    });

    test('sin permiso no busca la posición', () async {
      plataforma.permiso = LocationPermission.deniedForever;

      expect(await precisiones(servicio.afinarPosicion()), isEmpty);
      expect(plataforma.seguimientos, 0);
    });

    test('termina aunque el GPS no responda', () async {
      final sinSenal = StreamController<Position>();
      addTearDown(sinSenal.close);
      plataforma.lecturas = () => sinSenal.stream;

      expect(
        await precisiones(
            servicio.afinarPosicion(limite: const Duration(milliseconds: 50))),
        isEmpty,
      );
    });
  });
}
