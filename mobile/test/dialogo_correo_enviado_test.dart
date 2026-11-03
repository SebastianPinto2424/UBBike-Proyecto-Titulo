import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/features/autenticacion/presentation/dialogo_correo_enviado.dart';

const _mensaje =
    'Registro recibido. Revisa tu correo para activar la cuenta. Si no lo ves en unos minutos, revisa la carpeta de spam.';

Future<void> _abrirAviso(WidgetTester tester, String correo) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    DialogoCorreoEnviado(correo: correo, mensaje: _mensaje),
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

void main() {
  testWidgets('muestra a qué correo se envió el enlace y el aviso de spam',
      (tester) async {
    await _abrirAviso(tester, 'ana.rojas@alumnos.ubiobio.cl');

    expect(find.text('Correo enviado'), findsOneWidget);
    expect(
      find.textContaining('Enviamos un enlace a ana.rojas@alumnos.ubiobio.cl.',
          findRichText: true),
      findsOneWidget,
    );
    expect(find.text(_mensaje), findsOneWidget);
  });

  testWidgets('un correo largo no se sale del aviso en un celular angosto',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _abrirAviso(tester, 'catalina.fernandez2024@alumnos.ubiobio.cl');

    expect(tester.takeException(), isNull);
    expect(find.text('Volver al ingreso'), findsOneWidget);
  });

  testWidgets('volver al ingreso cierra solo el aviso', (tester) async {
    await _abrirAviso(tester, 'ana.rojas@alumnos.ubiobio.cl');

    await tester.tap(find.text('Volver al ingreso'));
    await tester.pumpAndSettle();

    expect(find.byType(DialogoCorreoEnviado), findsNothing);
    expect(find.text('Abrir'), findsOneWidget);
  });
}
