import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/features/admin/presentation/vista_gestion_usuarios.dart';

import 'soporte_api_falsa.dart';

Map<String, dynamic> _usuario({
  String id = 'u1',
  String nombre = 'Ana Rojas',
  String correo = 'ana@alumnos.ubiobio.cl',
  String rol = 'ESTUDIANTE',
  bool activa = true,
  bool verificado = true,
}) =>
    {
      'id': id,
      'nombre': nombre,
      'correo': correo,
      'rut': '11.111.111-1',
      'rol': rol,
      'correoVerificado': verificado,
      'registroParcial': false,
      'cuentaActiva': activa,
      'debeCambiarContrasena': false,
    };

Future<ApiFalsa> _montar(
  WidgetTester tester, {
  List<Map<String, dynamic>>? usuarios,
  Map<String, Object?> extra = const {},
}) =>
    montarConApi(
      tester,
      const VistaGestionUsuarios(),
      rol: RolUsuario.administrador,
      rutas: {
        'GET /usuarios': {
          'usuarios': usuarios ??
              [
                _usuario(),
                _usuario(
                  id: 'g1',
                  nombre: 'Pedro Soto',
                  correo: 'guardia@ubiobio.cl',
                  rol: 'GUARDIA',
                ),
              ],
        },
        ...extra,
      },
    );

Iterable<Map<String, String>> _consultas(ApiFalsa api) => api.peticiones
    .where((p) => p.method == 'GET' && p.url.path == '/usuarios')
    .map((p) => p.url.queryParameters);

void main() {
  testWidgets('lista las cuentas con su rol y estado', (tester) async {
    await _montar(tester);

    expect(find.text('Usuarios y permisos'), findsOneWidget);
    expect(find.text('Ana Rojas'), findsOneWidget);
    expect(find.text('Pedro Soto'), findsOneWidget);
    expect(find.text('Guardia'), findsWidgets);
  });

  testWidgets('sin cuentas muestra el estado vacío', (tester) async {
    await _montar(tester, usuarios: []);

    expect(find.text('Sin usuarios'), findsOneWidget);
  });

  testWidgets('si el backend falla lo informa', (tester) async {
    await montarConApi(
      tester,
      const VistaGestionUsuarios(),
      rol: RolUsuario.administrador,
      rutas: {'GET /usuarios': const RespuestaFalsa(500)},
    );

    expect(find.text('No se pudieron cargar usuarios'), findsOneWidget);
  });

  testWidgets('buscar envía el texto al backend', (tester) async {
    final api = await _montar(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre, correo o RUT'),
      ' ana ',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(_consultas(api).last['q'], 'ana');
    expect(find.text('Busca: ana'), findsOneWidget);
  });

  testWidgets('filtrar por rol consulta solo ese rol', (tester) async {
    final api = await _montar(tester);

    await tocarTexto(tester, 'Filtros');
    await tocar(
      tester,
      find.descendant(
        of: find.byType(ExpansionTile),
        matching: find.text('Guardia'),
      ),
    );

    expect(_consultas(api).last['rol'], 'GUARDIA');
  });

  testWidgets('crear una cuenta valida los datos y la envía', (tester) async {
    final api = await _montar(
      tester,
      extra: {
        'POST /usuarios': {
          'usuario': _usuario(
            id: 'n1',
            nombre: 'Camila Andrea Torres Vega',
            correo: 'ctorres@ubiobio.cl',
            rol: 'FUNCIONARIO',
            verificado: false,
          ),
        },
      },
    );

    await tocarTexto(tester, 'Usuario');
    await tocarTexto(tester, 'Crear');
    expect(find.text('El nombre es obligatorio.'), findsOneWidget);
    expect(find.text('Ingresa un correo.'), findsOneWidget);
    expect(find.text('El RUT es obligatorio.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre completo'),
      'Camila Andrea Torres Vega',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo'),
      'ctorres@ubiobio.cl',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'RUT'),
      '11.111.111-1',
    );
    await tocarTexto(tester, 'Crear');

    final cuerpo = api.cuerpoDe('POST /usuarios');
    expect(cuerpo['nombre'], 'Camila Andrea Torres Vega');
    expect(cuerpo['correo'], 'ctorres@ubiobio.cl');
    expect(find.text('Cuenta creada. Se envio el correo de acceso.'),
        findsOneWidget);
  });

  testWidgets('un RUT con dígito verificador incorrecto se rechaza',
      (tester) async {
    final api = await _montar(tester);

    await tocarTexto(tester, 'Usuario');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'RUT'),
      '11.111.111-2',
    );
    await tocarTexto(tester, 'Crear');

    expect(
      find.text('RUT inválido. Revisa el número y el dígito verificador.'),
      findsOneWidget,
    );
    expect(api.llamadas, isNot(contains('POST /usuarios')));
  });

  testWidgets('denegar el acceso actualiza los permisos', (tester) async {
    final api = await _montar(
      tester,
      usuarios: [_usuario()],
      extra: {
        'PATCH /usuarios/u1/permisos': {
          'usuario': _usuario(activa: false),
        },
      },
    );

    await tocarTexto(tester, 'Ana Rojas');
    await tocar(tester, find.byType(Switch));

    expect(api.cuerpoDe('PATCH /usuarios/u1/permisos')['cuentaActiva'], false);
    expect(find.text('Permisos actualizados'), findsOneWidget);
  });

  testWidgets('un error al actualizar muestra el mensaje del backend',
      (tester) async {
    await _montar(
      tester,
      usuarios: [_usuario()],
      extra: {
        'PATCH /usuarios/u1/permisos': const RespuestaFalsa(
          409,
          {'message': 'No puedes quitarte el acceso a ti mismo'},
        ),
      },
    );

    await tocarTexto(tester, 'Ana Rojas');
    await tocar(tester, find.byType(Switch));

    expect(
        find.text('No puedes quitarte el acceso a ti mismo'), findsOneWidget);
  });

  testWidgets('reenviar la verificación usa su ruta', (tester) async {
    final api = await _montar(
      tester,
      usuarios: [_usuario(verificado: false)],
      extra: {'POST /usuarios/u1/reenviar-verificacion': const {}},
    );

    await tocarTexto(tester, 'Ana Rojas');
    await tocarTexto(tester, 'Reenviar verificación');

    expect(api.llamadas, contains('POST /usuarios/u1/reenviar-verificacion'));
    expect(find.text('Correo de verificación reenviado'), findsOneWidget);
  });

  testWidgets('eliminar una cuenta pide confirmación', (tester) async {
    final api = await _montar(
      tester,
      usuarios: [_usuario()],
      extra: {'DELETE /usuarios/u1': const {}},
    );

    await tocarTexto(tester, 'Ana Rojas');
    await tocarTexto(tester, 'Eliminar cuenta');
    expect(find.text('Eliminar cuenta'), findsWidgets);

    await tester.tap(find.byKey(const Key('eliminar-confirmar')));
    await tester.pumpAndSettle();

    expect(api.llamadas, contains('DELETE /usuarios/u1'));
    expect(find.text('Cuenta eliminada'), findsOneWidget);
  });

  testWidgets('el correo de una cuenta nueva debe calzar con el rol',
      (tester) async {
    final api = await _montar(tester);

    await tocarTexto(tester, 'Usuario');
    await tocar(tester, find.text('Guardia').last);
    await tocarTexto(tester, 'Estudiante');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre completo'),
      'Camila Andrea Torres Vega',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo'),
      'ctorres@ubiobio.cl',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'RUT'),
      '11.111.111-1',
    );
    await tocarTexto(tester, 'Crear');

    expect(
      find.text('Un estudiante debe usar un correo @alumnos.ubiobio.cl'),
      findsOneWidget,
    );
    expect(api.llamadas, isNot(contains('POST /usuarios')));
  });

  testWidgets('al editar no acepta un correo externo para un estudiante',
      (tester) async {
    final api = await _montar(tester, usuarios: [_usuario()]);

    await tocarTexto(tester, 'Ana Rojas');
    await tocarTexto(tester, 'Editar datos');
    expect(find.text('Debe terminar en @alumnos.ubiobio.cl'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo'),
      'ana.rojas@gmail.com',
    );
    await tocarTexto(tester, 'Guardar');

    expect(
      find.text('Un estudiante debe usar un correo @alumnos.ubiobio.cl'),
      findsOneWidget,
    );
    expect(api.llamadas, isNot(contains('PATCH /usuarios/u1/permisos')));
  });
}
