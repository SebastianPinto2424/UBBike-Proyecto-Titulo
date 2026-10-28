import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';

class _ClienteInestable extends http.BaseClient {
  _ClienteInestable({required this.fallos, required this.error});

  int fallos;
  final Object error;
  int intentos = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    intentos++;
    if (fallos > 0) {
      fallos--;
      throw error;
    }
    final cuerpo = utf8.encode(jsonEncode({'ok': true}));
    return http.StreamedResponse(Stream.value(cuerpo), 200);
  }
}

void main() {
  group('reintento de lecturas', () {
    test('un corte puntual no llega a la pantalla', () async {
      final cliente = _ClienteInestable(
          fallos: 1, error: http.ClientException('conexión perdida'));
      final api = ClienteApi(httpClient: cliente);

      final respuesta = await api.get('/historial');

      expect(respuesta['ok'], isTrue);
      expect(cliente.intentos, 2);
    });

    test('reintenta hasta dos veces antes de rendirse', () async {
      final cliente = _ClienteInestable(
          fallos: 2, error: http.ClientException('conexión perdida'));
      final api = ClienteApi(httpClient: cliente);

      await api.get('/historial');

      expect(cliente.intentos, 3);
    });

    test('si el corte persiste informa el error', () async {
      final cliente =
          _ClienteInestable(fallos: 99, error: http.ClientException('sin red'));
      final api = ClienteApi(httpClient: cliente);

      await expectLater(
          api.get('/historial'),
          throwsA(isA<ExcepcionApi>()
              .having((e) => e.mensaje, 'mensaje', mensajeSinConexion)));
      expect(cliente.intentos, 3);
    });

    test('tambien reintenta cuando la peticion expira', () async {
      final cliente = _ClienteInestable(
          fallos: 1, error: TimeoutException('demoró demasiado'));
      final api = ClienteApi(httpClient: cliente);

      await api.get('/historial');

      expect(cliente.intentos, 2);
    });

    test('un error del servidor no se reintenta: no es transitorio', () async {
      var intentos = 0;
      final cliente = MockClient((_) async {
        intentos++;
        return http.Response(jsonEncode({'message': 'Dato inválido'}), 400);
      });
      final api = ClienteApi(httpClient: cliente);

      await expectLater(api.get('/historial'), throwsA(isA<ExcepcionApi>()));
      expect(intentos, 1);
    });

    test('las escrituras nunca se reintentan solas', () async {
      final cliente = _ClienteInestable(
          fallos: 1, error: http.ClientException('conexión perdida'));
      final api = ClienteApi(httpClient: cliente);

      await expectLater(
          api.post('/incidencias'),
          throwsA(isA<ExcepcionApi>()
              .having((e) => e.mensaje, 'mensaje', mensajeSinConexion)));
      expect(cliente.intentos, 1);
    });
  });
}

class MockClient extends http.BaseClient {
  MockClient(this.responder);
  final Future<http.Response> Function(http.BaseRequest) responder;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final respuesta = await responder(request);
    return http.StreamedResponse(
        Stream.value(utf8.encode(respuesta.body)), respuesta.statusCode);
  }
}
