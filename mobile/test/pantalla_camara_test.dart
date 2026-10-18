import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/shared/widgets/pantalla_camara.dart';

Future<void> _abrir(
  WidgetTester tester,
  Future<List<CameraDescription>> Function() buscarCamaras,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: crearTemaUbb(),
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PantallaCamara(buscarCamaras: buscarCamaras),
              ),
            ),
            child: const Text('abrir cámara'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir cámara'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin permiso de cámara lo explica y permite volver',
      (tester) async {
    await _abrir(
      tester,
      () async => throw CameraException('CameraAccessDenied', 'sin permiso'),
    );

    expect(find.text('Permite el uso de la cámara para tomar la foto.'),
        findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(PantallaCamara), findsNothing);
  });

  testWidgets('avisa si el dispositivo no tiene cámara', (tester) async {
    await _abrir(tester, () async => const []);

    expect(find.text('Este dispositivo no tiene una cámara disponible.'),
        findsOneWidget);
  });
}
