import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/app/principal/puente_tiempo_real.dart';
import 'package:ubbike/core/servicios/tiempo_real_servicio.dart';

class _ServicioFalso extends TiempoRealServicio {
  final avisos = StreamController<void>.broadcast();

  @override
  Stream<void> get rechazos => avisos.stream;
}

PuenteTiempoReal _puente(
  _ServicioFalso servicio,
  Future<void> Function() alRenovarSesion,
) =>
    PuenteTiempoReal(
      alCambiarConexion: (_) {},
      alCambiarVersion: (_) {},
      alEventoQr: (_) {},
      alCerrarSesionRemota: () {},
      alRenovarSesion: alRenovarSesion,
      servicio: servicio,
    );

void main() {
  test('distingue un rechazo del servidor de una caída de red', () {
    expect(
      esRechazoDelServidor({'message': 'Token de tiempo real inválido'}),
      isTrue,
    );
    expect(
      esRechazoDelServidor(
          {'msg': 'websocket error', 'type': 'TransportError'}),
      isFalse,
    );
    expect(esRechazoDelServidor('timeout'), isFalse);
    expect(esCierreDelServidor('io server disconnect'), isTrue);
    expect(esCierreDelServidor('transport close'), isFalse);
    expect(esCierreDelServidor('io client disconnect'), isFalse);
  });

  test('si el servidor rechaza el socket renueva la sesión una sola vez',
      () async {
    final servicio = _ServicioFalso();
    var renovaciones = 0;
    final puente = _puente(servicio, () async {
      renovaciones++;
    });

    servicio.avisos
      ..add(null)
      ..add(null)
      ..add(null);
    await Future<void>.delayed(Duration.zero);

    expect(renovaciones, 1);
    puente.dispose();
  });

  test('si la renovación falla el puente sigue funcionando', () async {
    final servicio = _ServicioFalso();
    final puente = _puente(servicio, () async {
      throw Exception('Sin conexión');
    });

    servicio.avisos.add(null);
    await Future<void>.delayed(Duration.zero);

    puente.dispose();
  });
}
