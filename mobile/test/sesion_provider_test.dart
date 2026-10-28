import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';

const usuarioJson = {
  'id': 'u',
  'nombre': 'Usuario Prueba',
  'correo': 'test@ubiobio.cl',
  'rol': 'ADMINISTRADOR',
  'correoVerificado': true
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({
        'ubbike_jwt': 'viejo',
        'ubbike_refresh': 'r1',
        'ubbike_usuario_id': 'u'
      }));
  test('restaura renovando el JWT y persiste ambos tokens', () async {
    final c = ProviderContainer(overrides: [
      sesionHttpProvider.overrideWithValue(MockClient((r) async {
        if (r.url.path.endsWith('/refresh')) {
          return http.Response('{"token":"nuevo","refreshToken":"r2"}', 200);
        }
        return http.Response(jsonEncode({'usuario': usuarioJson}),
            r.headers['Authorization'] == 'Bearer nuevo' ? 200 : 401);
      }))
    ]);
    addTearDown(c.dispose);
    final sesion = await c.read(sesionProvider.future) as SesionActiva;
    expect(sesion.token, 'nuevo');
    expect(
        await const FlutterSecureStorage().read(key: 'ubbike_refresh'), 'r2');
  });
  test('error de red al restaurar mantiene credenciales para reintentar',
      () async {
    final c = ProviderContainer(overrides: [
      sesionHttpProvider.overrideWithValue(
          MockClient((_) async => throw http.ClientException('offline')))
    ]);
    addTearDown(c.dispose);
    await expectLater(
        c.read(sesionProvider.future),
        throwsA(isA<ExcepcionApi>()
            .having((e) => e.mensaje, 'mensaje', mensajeSinConexion)));
    expect(await const FlutterSecureStorage().read(key: 'ubbike_jwt'), 'viejo');
  });
  test('rechazo definitivo limpia las credenciales', () async {
    final c = ProviderContainer(overrides: [
      sesionHttpProvider
          .overrideWithValue(MockClient((_) async => http.Response('{}', 401)))
    ]);
    addTearDown(c.dispose);
    expect(await c.read(sesionProvider.future), isA<SesionVacia>());
    expect(await const FlutterSecureStorage().read(key: 'ubbike_jwt'), isNull);
  });
  test('cerrar durante una escritura de renovación no revive la sesión',
      () async {
    final c = ProviderContainer(overrides: [
      sesionHttpProvider.overrideWithValue(MockClient((_) async =>
          http.Response(jsonEncode({'usuario': usuarioJson}), 200)))
    ]);
    addTearDown(c.dispose);
    await c.read(sesionProvider.future);
    final vm = c.read(sesionProvider.notifier);
    await Future.wait([vm.actualizarToken('nuevo', 'r2'), vm.olvidar()]);
    expect(c.read(sesionProvider).valueOrNull, isA<SesionVacia>());
    expect(await const FlutterSecureStorage().read(key: 'ubbike_jwt'), isNull);
  });
  test('login sin refresh no hereda el de una cuenta anterior', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(sesionProvider.future);
    await c.read(sesionProvider.notifier).iniciar(
        token: 'a',
        usuario: UsuarioApp.fromJson(usuarioJson),
        refreshToken: 'r1');
    await c
        .read(sesionProvider.notifier)
        .iniciar(token: 'b', usuario: UsuarioApp.fromJson(usuarioJson));
    expect(
        await const FlutterSecureStorage().read(key: 'ubbike_refresh'), isNull);
  });

  test('al abrirse la cuenta en otro dispositivo se cierra con el motivo',
      () async {
    final c = ProviderContainer(overrides: [
      sesionHttpProvider.overrideWithValue(MockClient((r) async =>
          http.Response(jsonEncode({'usuario': usuarioJson}), 200))),
    ]);
    addTearDown(c.dispose);
    expect(await c.read(sesionProvider.future), isA<SesionActiva>());

    await c.read(sesionProvider.notifier).cerrarPorOtroDispositivo();

    final sesion = c.read(sesionProvider).value;
    expect(sesion, isA<SesionVacia>());
    expect((sesion as SesionVacia).motivo, mensajeSesionEnOtroDispositivo);
    expect(await const FlutterSecureStorage().read(key: 'ubbike_jwt'), isNull);
  });
}
