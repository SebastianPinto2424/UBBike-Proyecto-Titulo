import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/core/providers/cliente_api_provider.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';

class RespuestaFalsa {
  const RespuestaFalsa(this.estado, [this.cuerpo = const {}]);

  final int estado;
  final Map<String, dynamic> cuerpo;
}

typedef ManejadorRuta = Object? Function(http.Request peticion);

class ApiFalsa {
  ApiFalsa(Map<String, Object?> rutas)
      : _rutas = {
          for (final entrada in rutas.entries)
            entrada.key: entrada.value is ManejadorRuta
                ? entrada.value as ManejadorRuta
                : (_) => entrada.value,
        };

  final Map<String, ManejadorRuta> _rutas;
  final peticiones = <http.Request>[];

  void responder(String ruta, Object? respuesta) =>
      _rutas[ruta] = (_) => respuesta;

  List<String> get llamadas =>
      peticiones.map((p) => '${p.method} ${p.url.path}').toList();

  Map<String, dynamic> cuerpoDe(String ruta) {
    final peticion = peticiones.lastWhere(
      (p) => '${p.method} ${p.url.path}' == ruta,
    );
    return jsonDecode(peticion.body) as Map<String, dynamic>;
  }

  http.Client get cliente => MockClient((peticion) async {
        peticiones.add(peticion);
        final clave = '${peticion.method} ${peticion.url.path}';
        final manejador = _rutas[clave];
        if (manejador == null) {
          return http.Response(
            jsonEncode({'message': 'Ruta no simulada: $clave'}),
            404,
          );
        }
        final respuesta = manejador(peticion);
        if (respuesta is RespuestaFalsa) {
          return http.Response(
            jsonEncode(respuesta.cuerpo),
            respuesta.estado,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode(respuesta ?? const {}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
}

UsuarioApp usuarioDePrueba(RolUsuario rol) => UsuarioApp(
      id: 'yo',
      nombre: 'Persona de Prueba',
      correo: rol == RolUsuario.estudiante
          ? 'persona@alumnos.ubiobio.cl'
          : 'persona@ubiobio.cl',
      rol: rol,
      correoVerificado: true,
      registroParcial: false,
      cuentaActiva: true,
    );

class _SesionDePrueba extends SesionNotifier {
  _SesionDePrueba(this.usuario);

  final UsuarioApp usuario;

  @override
  Future<EstadoSesion> build() async =>
      SesionActiva(usuario: usuario, token: 'token-prueba');
}

Future<ApiFalsa> montarConApi(
  WidgetTester tester,
  Widget pantalla, {
  required Map<String, Object?> rutas,
  RolUsuario rol = RolUsuario.estudiante,
  List<Override> overrides = const [],
  bool conScaffold = true,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  final api = ApiFalsa(rutas);
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionProvider
            .overrideWith(() => _SesionDePrueba(usuarioDePrueba(rol))),
        clienteApiProvider.overrideWithValue(
          ClienteApi(
            httpClient: api.cliente,
            obtenerToken: () => 'token-prueba',
          ),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: crearTemaUbb(),
        home: conScaffold ? Scaffold(body: pantalla) : pantalla,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Future<void> tocar(WidgetTester tester, Finder finder) async {
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }
  await tester.tap(finder.hitTestable().last);
  await tester.pumpAndSettle();
}

Future<void> tocarTexto(WidgetTester tester, String texto) =>
    tocar(tester, find.text(texto));
