import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/shared/utils/utiles_comun.dart';
import 'package:ubbike/shared/widgets/visor_foto.dart';

const _pngMinimo =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

Future<void> _abrirFoto(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: crearTemaUbb(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => mostrarFotoBicicletaAmpliada(context, _pngMinimo),
            child: const Text('ver foto'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ver foto'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la foto ampliada ocupa toda la pantalla', (tester) async {
    await _abrirFoto(tester);

    final pantalla = tester.getSize(find.byType(VisorFoto));
    expect(tester.getSize(find.byType(Image)), pantalla);
  });

  testWidgets('el doble toque acerca la foto y otro doble toque la devuelve',
      (tester) async {
    await _abrirFoto(tester);
    final visor = find.byType(InteractiveViewer);
    Matrix4 transformacion() =>
        tester.widget<InteractiveViewer>(visor).transformationController!.value;

    Future<void> dobleToque() async {
      await tester.tap(visor);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(visor);
      await tester.pumpAndSettle();
    }

    await dobleToque();
    expect(transformacion().getMaxScaleOnAxis(), greaterThan(1));

    await dobleToque();
    expect(transformacion(), Matrix4.identity());
  });

  testWidgets('la X cierra la foto', (tester) async {
    await _abrirFoto(tester);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.byType(VisorFoto), findsNothing);
  });
}
