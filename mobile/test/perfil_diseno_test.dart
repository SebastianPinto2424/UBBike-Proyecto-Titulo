import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/perfil/presentation/pantalla_principal_perfil.dart';
import 'package:ubbike/shared/modelos/rol_usuario.dart';
import 'package:ubbike/shared/modelos/usuario_app.dart';

UsuarioApp _usuario({
  String nombre = 'Administrador UBBike',
  String correo = 'administrador@ubiobio.cl',
  String? rut = '11.555.555-5',
  bool correoVerificado = true,
  bool cuentaActiva = true,
}) {
  return UsuarioApp(
    id: 'u1',
    nombre: nombre,
    correo: correo,
    rut: rut,
    rol: RolUsuario.administrador,
    correoVerificado: correoVerificado,
    registroParcial: false,
    cuentaActiva: cuentaActiva,
  );
}

Widget _app(UsuarioApp usuario, {double escala = 1.0}) {
  return ProviderScope(
    overrides: [
      sesionProvider.overrideWith(() => _SesionFalsa(usuario)),
    ],
    child: MaterialApp(
      theme: crearTemaUbb(),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: escala,
        maxScaleFactor: escala,
        child: child!,
      ),
      home: const Scaffold(
        body: VistaPerfil(rol: RolUsuario.administrador),
      ),
    ),
  );
}

class _SesionFalsa extends SesionNotifier {
  _SesionFalsa(this.usuario);

  final UsuarioApp usuario;

  @override
  Future<SesionState> build() async =>
      SesionActiva(usuario: usuario, token: 'test');
}

void main() {
  testWidgets('muestra identidad, datos y seguridad sin desbordes',
      (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_usuario()));
    await tester.pumpAndSettle();

    expect(find.text('Administrador UBBike'), findsOneWidget);
    expect(find.text('AU'), findsOneWidget);
    expect(find.text('Datos de la cuenta'), findsOneWidget);
    expect(find.text('administrador@ubiobio.cl'), findsOneWidget);
    expect(find.text('11.555.555-5'), findsOneWidget);
    expect(find.text('Seguridad'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con el correo verificado no aparece ninguna etiqueta de correo',
      (tester) async {
    await tester.pumpWidget(_app(_usuario()));
    await tester.pumpAndSettle();

    expect(find.text('Correo verificado'), findsNothing);
    expect(find.text('Verificación pendiente'), findsNothing);
  });

  testWidgets('avisa cuando la verificación está pendiente', (tester) async {
    await tester.pumpWidget(_app(_usuario(correoVerificado: false)));
    await tester.pumpAndSettle();

    expect(find.text('Verificación pendiente'), findsOneWidget);
  });

  testWidgets('avisa cuando la cuenta está suspendida', (tester) async {
    await tester.pumpWidget(_app(_usuario(cuentaActiva: false)));
    await tester.pumpAndSettle();

    expect(find.text('Cuenta suspendida'), findsOneWidget);
  });

  testWidgets('tocar el correo lo copia al portapapeles', (tester) async {
    String? copiado;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (llamada) async {
        if (llamada.method == 'Clipboard.setData') {
          copiado = (llamada.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(_app(_usuario()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('administrador@ubiobio.cl'));
    await tester.pumpAndSettle();

    expect(copiado, 'administrador@ubiobio.cl');
  });

  testWidgets('sin RUT registrado la fila no ofrece copiar', (tester) async {
    await tester.pumpWidget(_app(_usuario(rut: null)));
    await tester.pumpAndSettle();

    expect(find.text('Sin RUT registrado'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });

  testWidgets('sobrevive a nombres largos con escala de texto 1.8',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        _usuario(nombre: 'Esmeralda Caroline Pinto Rivera de los Santos'),
        escala: 1.8,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
