import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/app/principal/puente_tiempo_real.dart';
import 'package:ubbike/core/servicios/tiempo_real_servicio.dart';

class _ServicioFalso extends TiempoRealServicio {
  final avisos = StreamController<void>.broadcast();
  final cierres = StreamController<String?>.broadcast();

  @override
  Stream<void> get rechazos => avisos.stream;

  @override
  Stream<String?> get sesionCerrada => cierres.stream;
}

PuenteTiempoReal _puente(
  _ServicioFalso servicio,
  Future<void> Function() alRenovarSesion, {
  void Function(String? motivo)? alCerrarSesionRemota,
}) =>
    PuenteTiempoReal(
      alCambiarConexion: (_) {},
      alCambiarVersion: (_) {},
      alEventoQr: (_) {},
      alCerrarSesionRemota: alCerrarSesionRemota ?? (_) {},
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

  test('lee el motivo del aviso de cierre de sesión', () {
    expect(
        motivoCierreSesion({'motivo': 'CUENTA_ELIMINADA'}), 'CUENTA_ELIMINADA');
    expect(motivoCierreSesion({'motivo': 3}), isNull);
    expect(motivoCierreSesion(null), isNull);
  });

  test('al cerrar la sesión desde el servidor entrega el motivo', () async {
    final servicio = _ServicioFalso();
    final motivos = <String?>[];
    final puente = _puente(
      servicio,
      () async {},
      alCerrarSesionRemota: motivos.add,
    );

    servicio.cierres
      ..add('CUENTA_ELIMINADA')
      ..add(null);
    await Future<void>.delayed(Duration.zero);

    expect(motivos, ['CUENTA_ELIMINADA', null]);
    puente.dispose();
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
