import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/shared/widgets/dialogo_correo_enviado.dart';

const _nota = 'Al cambiarla, cerraremos tu sesión en todos tus equipos.';

Future<void> _abrirAviso(
  WidgetTester tester, {
  String proposito = 'activar tu cuenta',
  String? correo = 'ana.rojas@alumnos.ubiobio.cl',
  String? nota,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => DialogoCorreoEnviado(
                  proposito: proposito,
                  correo: correo,
                  nota: nota,
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

InlineSpan _envio(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('texto-envio'))).textSpan!;

String _textoEnvio(WidgetTester tester) =>
    _envio(tester).toPlainText(includeSemanticsLabels: false);

void main() {
  testWidgets('al registrarse indica dentro de la frase a qué correo se envió',
      (tester) async {
    await _abrirAviso(tester);

    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(
      _textoEnvio(tester),
      'Enviamos un enlace para activar tu cuenta a '
      'ana.rojas@\u200Balumnos.ubiobio.cl.',
    );
    expect(
      _envio(tester).toPlainText(),
      'Enviamos un enlace para activar tu cuenta a '
      'ana.rojas@alumnos.ubiobio.cl.',
    );
    expect(find.text('¿No lo ves? Revisa la carpeta de spam.'), findsOneWidget);
  });

  testWidgets('sin correo no lo repite', (tester) async {
    await _abrirAviso(tester,
        proposito: 'cambiar tu contraseña', correo: null, nota: _nota);

    expect(_textoEnvio(tester),
        'Te enviamos un enlace para cambiar tu contraseña.');
    expect(find.textContaining('@'), findsNothing);
    expect(find.text(_nota), findsOneWidget);
  });

  testWidgets('la nota aparece solo cuando se entrega', (tester) async {
    await _abrirAviso(tester);

    expect(find.text(_nota), findsNothing);
  });

  testWidgets('un correo largo no se sale del aviso en un celular angosto',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _abrirAviso(tester,
        correo: 'catalina.fernandez2024@alumnos.ubiobio.cl', nota: _nota);

    expect(tester.takeException(), isNull);
    expect(find.text('Entendido'), findsOneWidget);
  });

  testWidgets('el botón cierra solo el aviso', (tester) async {
    await _abrirAviso(tester);

    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    expect(find.byType(DialogoCorreoEnviado), findsNothing);
    expect(find.text('Abrir'), findsOneWidget);
  });
}
