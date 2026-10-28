import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';

void main() {
  test(
      'dos clientes comparten una sola renovación y reintentan con el JWT nuevo',
      () async {
    var token = 'viejo';
    var refresh = 'r1';
    var renovaciones = 0;
    final barrera = Completer<void>();
    final httpClient = MockClient((r) async {
      if (r.url.path.endsWith('/refresh')) {
        renovaciones++;
        await barrera.future;
        return http.Response(
            jsonEncode({'token': 'nuevo', 'refreshToken': 'r2'}), 200);
      }
      return http.Response(
          '{}', r.headers['Authorization'] == 'Bearer nuevo' ? 200 : 401);
    });
    ClienteApi cliente() => ClienteApi(
        httpClient: httpClient,
        obtenerToken: () => token,
        obtenerRefreshToken: () => refresh,
        obtenerUsuarioId: () => 'usuario',
        alActualizarTokens: (t, r) async {
          token = t;
          refresh = r!;
        });
    final a = cliente().get('/perfil');
    final b = cliente().getBytes('/reporte');
    await Future<void>.delayed(Duration.zero);
    barrera.complete();
    await Future.wait([a, b]);
    expect(renovaciones, 1);
    expect(token, 'nuevo');
    expect(refresh, 'r2');
  });

  for (final status in [500, 503]) {
    test('un refresh $status no cierra la sesión', () async {
      var expirada = false;
      final cliente = ClienteApi(
          httpClient: MockClient((r) async => http.Response(
              '{}', r.url.path.endsWith('/refresh') ? status : 401)),
          obtenerToken: () => 't',
          obtenerRefreshToken: () => 'r$status',
          obtenerUsuarioId: () => 'u',
          alActualizarTokens: (_, __) async {},
          alExpirarSesion: () async {
            expirada = true;
          });
      await expectLater(
          cliente.get('/perfil'),
          throwsA(isA<ExcepcionApi>()
              .having((e) => e.statusCode, 'status', status)));
      expect(expirada, false);
    });
  }
  test('fallo de red al renovar conserva la sesión', () async {
    var expirada = false;
    final cliente = ClienteApi(
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('/refresh')) {
            throw http.ClientException('sin red');
          }
          return http.Response('{}', 401);
        }),
        obtenerToken: () => 't',
        obtenerRefreshToken: () => 'offline',
        obtenerUsuarioId: () => 'u',
        alActualizarTokens: (_, __) async {},
        alExpirarSesion: () async {
          expirada = true;
        });
    await expectLater(
        cliente.get('/perfil'),
        throwsA(isA<ExcepcionApi>()
            .having((e) => e.mensaje, 'mensaje', mensajeSinConexion)));
    expect(expirada, false);
  });
  test('refresh rechazado expira la sesión una vez', () async {
    var expiraciones = 0;
    final cliente = ClienteApi(
        httpClient: MockClient((_) async => http.Response('{}', 401)),
        obtenerToken: () => 't',
        obtenerRefreshToken: () => 'rechazado',
        obtenerUsuarioId: () => 'u',
        alActualizarTokens: (_, __) async {},
        alExpirarSesion: () async {
          expiraciones++;
        });
    await expectLater(cliente.get('/perfil'), throwsA(isA<ExcepcionApi>()));
    expect(expiraciones, 1);
  });
  test('renovación tardía no revive una sesión cerrada', () async {
    String? refresh = 'tardio';
    var actualizaciones = 0;
    final httpClient = MockClient((r) async {
      if (r.url.path.endsWith('/refresh')) {
        refresh = null;
        return http.Response('{"token":"nuevo","refreshToken":"r2"}', 200);
      }
      return http.Response('{}', 401);
    });
    final cliente = ClienteApi(
        httpClient: httpClient,
        obtenerToken: () => 't',
        obtenerRefreshToken: () => refresh,
        obtenerUsuarioId: () => 'u',
        alActualizarTokens: (_, __) async {
          actualizaciones++;
        });
    await expectLater(cliente.get('/perfil'), throwsA(isA<ExcepcionApi>()));
    expect(actualizaciones, 0);
  });
  test('toda petición tiene tiempo límite', () async {
    final cliente = ClienteApi(
        timeout: const Duration(milliseconds: 5),
        httpClient: MockClient((_) => Completer<http.Response>().future));
    await expectLater(
        cliente.get('/perfil'),
        throwsA(isA<ExcepcionApi>()
            .having((e) => e.mensaje, 'mensaje', mensajeSinConexion)));
  });
  test('un error 500 no muestra detalles del servidor', () async {
    final cliente = ClienteApi(
        httpClient: MockClient((_) async =>
            http.Response('{"message":"Error interno del servidor"}', 500)));
    await expectLater(
        cliente.get('/perfil'),
        throwsA(isA<ExcepcionApi>()
            .having((e) => e.mensaje, 'mensaje', mensajeServidorNoDisponible)
            .having((e) => e.statusCode, 'status', 500)));
  });
  test('una respuesta que no es JSON se trata como servidor no disponible',
      () async {
    final cliente = ClienteApi(
        httpClient: MockClient(
            (_) async => http.Response('<html>ERR_NGROK_3200</html>', 404)));
    await expectLater(
        cliente.post('/incidencias'),
        throwsA(isA<ExcepcionApi>()
            .having((e) => e.mensaje, 'mensaje', mensajeServidorNoDisponible)));
  });
  test('el código del error llega a la app', () async {
    final cliente = ClienteApi(
        httpClient: MockClient((_) async => http.Response(
            '{"message":"Aún no confirmas tu correo.","codigo":"CORREO_NO_VERIFICADO"}',
            403,
            headers: {'content-type': 'application/json; charset=utf-8'})));
    await expectLater(
        cliente.post('/autenticacion/login'),
        throwsA(isA<ExcepcionApi>()
            .having((e) => e.codigo, 'codigo', 'CORREO_NO_VERIFICADO')
            .having((e) => e.statusCode, 'status', 403)));
  });
  test('sin red una escritura avisa que no hay conexión', () async {
    final cliente = ClienteApi(
        httpClient:
            MockClient((_) async => throw http.ClientException('sin red')));
    await expectLater(
        cliente.post('/incidencias'),
        throwsA(isA<ExcepcionApi>()
            .having((e) => e.mensaje, 'mensaje', mensajeSinConexion)));
  });
}
