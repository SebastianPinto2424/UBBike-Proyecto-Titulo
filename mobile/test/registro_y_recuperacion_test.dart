import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/features/autenticacion/data/autenticacion_api.dart';
import 'package:ubbike/features/autenticacion/presentation/pantalla_inicio_sesion.dart';
import 'package:ubbike/features/autenticacion/presentation/pantalla_registro.dart';

import 'soporte_api_falsa.dart';

const _clave = 'Bicicleta#2026ubb';

Finder _campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

Finder _enlace(String texto) => find.textContaining(texto, findRichText: true);

Finder _enDialogo(String texto) => find.descendant(
      of: find.byType(AlertDialog),
      matching: _enlace(texto),
    );

Future<ApiFalsa> _montarInicioSesion(
  WidgetTester tester, [
  Map<String, Object?> rutas = const {},
]) =>
    montarConApi(
      tester,
      const PantallaInicioSesion(),
      conScaffold: false,
      rutas: rutas,
    );

Future<void> _llenarRegistro(
  WidgetTester tester, {
  String nombre = 'Ana María Rojas Soto',
  String rut = '11.111.111-1',
  String correo = 'ana.rojas@alumnos.ubiobio.cl',
  String clave = _clave,
}) async {
  await tester.enterText(_campo('Nombre completo'), nombre);
  await tester.enterText(_campo('RUT'), rut);
  await tester.enterText(_campo('Correo institucional'), correo);
  await tester.enterText(_campo('Contraseña'), clave);
}

void main() {
  group('registro', () {
    testWidgets('valida los datos antes de enviar', (tester) async {
      final api = await _montarInicioSesion(tester);
      await tocar(tester, _enlace('Registrarse'));
      expect(find.byType(PantallaRegistro), findsOneWidget);

      await tocarTexto(tester, 'Registrar');

      expect(find.text('El nombre es obligatorio.'), findsOneWidget);
      expect(find.text('El RUT es obligatorio.'), findsOneWidget);
      expect(find.text('El correo es obligatorio.'), findsOneWidget);
      expect(find.text('La contraseña es obligatoria.'), findsOneWidget);
      expect(api.llamadas, isEmpty);
    });

    testWidgets('exige correo institucional y RUT válido', (tester) async {
      final api = await _montarInicioSesion(tester);
      await tocar(tester, _enlace('Registrarse'));

      await _llenarRegistro(
        tester,
        rut: '11.111.111-2',
        correo: 'ana@gmail.com',
      );
      await tocarTexto(tester, 'Registrar');

      expect(find.text('Debe ser @ubiobio.cl o @alumnos.ubiobio.cl'),
          findsOneWidget);
      expect(
        find.text('RUT inválido. Revisa el número y el dígito verificador.'),
        findsOneWidget,
      );
      expect(api.llamadas, isEmpty);
    });

    testWidgets('envía el registro y vuelve al ingreso', (tester) async {
      final api = await _montarInicioSesion(tester, {
        'POST /autenticacion/registro': {
          'message': 'Te enviamos un correo para verificar tu cuenta.',
        },
      });
      await tocar(tester, _enlace('Registrarse'));

      await _llenarRegistro(tester);
      await tocarTexto(tester, 'Registrar');

      final cuerpo = api.cuerpoDe('POST /autenticacion/registro');
      expect(cuerpo['nombre'], 'Ana María Rojas Soto');
      expect(cuerpo['rut'], '11.111.111-1');
      expect(cuerpo['correo'], 'ana.rojas@alumnos.ubiobio.cl');
      expect(cuerpo['contrasena'], _clave);
      expect(find.text('Correo enviado'), findsOneWidget);
      expect(_enDialogo('Enviamos un enlace a ana.rojas@alumnos.ubiobio.cl.'),
          findsOneWidget);
      expect(find.text('Te enviamos un correo para verificar tu cuenta.'),
          findsOneWidget);

      await tocarTexto(tester, 'Volver al ingreso');

      expect(find.byType(PantallaRegistro), findsNothing);
      expect(find.byType(PantallaInicioSesion), findsOneWidget);
    });

    testWidgets('si el correo ya existe muestra el motivo', (tester) async {
      await _montarInicioSesion(tester, {
        'POST /autenticacion/registro': const RespuestaFalsa(
          409,
          {'message': 'El correo ya está registrado'},
        ),
      });
      await tocar(tester, _enlace('Registrarse'));

      await _llenarRegistro(tester);
      await tocarTexto(tester, 'Registrar');

      expect(find.text('El correo ya está registrado'), findsOneWidget);
      expect(find.text('Correo enviado'), findsNothing);
    });
  });

  group('inicio de sesión sin confirmar el correo', () {
    testWidgets('ofrece reenviar el enlace en vez de solo mostrar el error',
        (tester) async {
      final api = await _montarInicioSesion(tester, {
        'POST /autenticacion/login': const RespuestaFalsa(403, {
          'message': 'Aún no confirmas tu correo.',
          'codigo': 'CORREO_NO_VERIFICADO',
        }),
        'POST /autenticacion/reenviar-verificacion': {'message': 'ok'},
      });

      await tester.enterText(
          _campo('Correo electrónico'), 'ana@alumnos.ubiobio.cl');
      await tester.enterText(_campo('Contraseña'), _clave);
      await tocarTexto(tester, 'Ingresar');

      expect(find.text('Confirma tu correo'), findsOneWidget);
      expect(_enDialogo('ana@alumnos.ubiobio.cl'), findsOneWidget);

      await tocar(tester, find.byKey(const Key('reenviar-correo')));

      expect(api.cuerpoDe('POST /autenticacion/reenviar-verificacion'),
          {'correo': 'ana@alumnos.ubiobio.cl'});
      expect(find.text('Te enviamos un enlace nuevo.'), findsOneWidget);

      await tocarTexto(tester, 'Entendido');
      expect(find.text('Confirma tu correo'), findsNothing);
    });

    testWidgets('si el reenvío falla lo dice dentro del diálogo',
        (tester) async {
      await _montarInicioSesion(tester, {
        'POST /autenticacion/login': const RespuestaFalsa(403, {
          'message': 'Aún no confirmas tu correo.',
          'codigo': 'CORREO_NO_VERIFICADO',
        }),
        'POST /autenticacion/reenviar-verificacion': const RespuestaFalsa(429, {
          'message': 'Demasiadas solicitudes de reenvío. Intenta más tarde.',
        }),
      });

      await tester.enterText(
          _campo('Correo electrónico'), 'ana@alumnos.ubiobio.cl');
      await tester.enterText(_campo('Contraseña'), _clave);
      await tocarTexto(tester, 'Ingresar');
      await tocar(tester, find.byKey(const Key('reenviar-correo')));

      expect(find.text('Demasiadas solicitudes de reenvío. Intenta más tarde.'),
          findsOneWidget);
      expect(find.text('Reenviar correo'), findsOneWidget);

      await tocarTexto(tester, 'Entendido');
    });

    testWidgets('los demás errores se muestran como siempre', (tester) async {
      await _montarInicioSesion(tester, {
        'POST /autenticacion/login': const RespuestaFalsa(
          401,
          {'message': 'Credenciales inválidas'},
        ),
      });

      await tester.enterText(
          _campo('Correo electrónico'), 'ana@alumnos.ubiobio.cl');
      await tester.enterText(_campo('Contraseña'), _clave);
      await tocarTexto(tester, 'Ingresar');

      expect(find.text('Credenciales inválidas'), findsOneWidget);
      expect(find.text('Confirma tu correo'), findsNothing);
    });
  });

  group('recuperación de contraseña', () {
    testWidgets('envía el enlace al correo indicado', (tester) async {
      final api = await _montarInicioSesion(tester, {
        'POST /autenticacion/solicitar-cambio-contrasena': {
          'message':
              'Si el correo existe, enviaremos instrucciones de recuperación.',
        },
      });

      await tester.enterText(
          _campo('Correo electrónico'), 'ana@alumnos.ubiobio.cl');
      await tocar(tester, _enlace('Recuperar'));
      expect(find.text('Recuperar contraseña'), findsOneWidget);
      expect(find.text('ana@alumnos.ubiobio.cl'), findsWidgets);

      await tocarTexto(tester, 'Enviar correo');

      expect(
        api.cuerpoDe(
            'POST /autenticacion/solicitar-cambio-contrasena')['correo'],
        'ana@alumnos.ubiobio.cl',
      );
      expect(
        find.text(
            'Si el correo existe, enviaremos instrucciones de recuperación.'),
        findsOneWidget,
      );
    });

    testWidgets('no envía sin un correo válido', (tester) async {
      final api = await _montarInicioSesion(tester);

      await tocar(tester, _enlace('Recuperar'));
      await tocarTexto(tester, 'Enviar correo');

      expect(find.text('Recuperar contraseña'), findsOneWidget);
      expect(api.llamadas, isEmpty);
    });
  });

  group('ingreso', () {
    testWidgets('credenciales incorrectas muestran el error', (tester) async {
      final api = await _montarInicioSesion(tester, {
        'POST /autenticacion/login': const RespuestaFalsa(
          401,
          {'message': 'Credenciales inválidas'},
        ),
      });

      await tester.enterText(
          _campo('Correo electrónico'), ' Ana@Alumnos.UBiobio.cl ');
      await tester.enterText(_campo('Contraseña'), 'Equivocada#2026');
      await tocarTexto(tester, 'Ingresar');

      expect(api.cuerpoDe('POST /autenticacion/login')['correo'],
          'ana@alumnos.ubiobio.cl');
      expect(find.textContaining('Credenciales'), findsOneWidget);
    });
  });

  group('API de autenticación', () {
    late ApiFalsa api;
    late AutenticacionApi autenticacion;

    setUp(() {
      api = ApiFalsa({
        'POST /autenticacion/login': {
          'token': 't1',
          'refreshToken': 'r1',
          'usuario': {
            'id': 'u1',
            'nombre': 'Ana Rojas',
            'correo': 'ana@alumnos.ubiobio.cl',
            'rol': 'ESTUDIANTE',
            'correoVerificado': true,
          },
        },
        'POST /autenticacion/refresh': {'token': 't2', 'refreshToken': 'r2'},
        'POST /autenticacion/cambiar-contrasena-sesion': {
          'message': 'Contraseña actualizada. Vuelve a iniciar sesión.',
        },
      });
      autenticacion =
          AutenticacionApi(cliente: ClienteApi(httpClient: api.cliente));
    });

    test('inicia sesión y entrega los tokens y el usuario', () async {
      final resultado = await autenticacion.iniciarSesion(
        correo: 'ana@alumnos.ubiobio.cl',
        contrasena: _clave,
      );

      expect(resultado.token, 't1');
      expect(resultado.refreshToken, 'r1');
      expect(resultado.usuario.nombre, 'Ana Rojas');
    });

    test('renueva los tokens', () async {
      final resultado = await autenticacion.refrescarToken(
          usuarioId: 'u1', refreshToken: 'r1');

      expect(resultado.token, 't2');
      expect(api.cuerpoDe('POST /autenticacion/refresh'),
          {'usuarioId': 'u1', 'refreshToken': 'r1'});
    });

    test('cambia la contraseña con la sesión abierta', () async {
      expect(
        await autenticacion.cambiarContrasenaSesion(
          contrasenaActual: 'Temporal#2026x',
          contrasenaNueva: _clave,
        ),
        'Contraseña actualizada. Vuelve a iniciar sesión.',
      );
      expect(
        api.cuerpoDe('POST /autenticacion/cambiar-contrasena-sesion'),
        containsPair('contrasenaActual', 'Temporal#2026x'),
      );
    });

    test('una contraseña actual incorrecta se informa como error de la API',
        () async {
      api.responder(
        'POST /autenticacion/cambiar-contrasena-sesion',
        const RespuestaFalsa(400, {
          'message': 'La contraseña actual no es correcta',
        }),
      );

      expect(
        () => autenticacion.cambiarContrasenaSesion(
          contrasenaActual: 'Equivocada#2026',
          contrasenaNueva: _clave,
        ),
        throwsA(
            isA<ExcepcionApi>().having((e) => e.statusCode, 'statusCode', 400)),
      );
    });
  });
}
