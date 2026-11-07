import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/shared/widgets/campo_solo_lectura.dart';

Future<void> _montar(WidgetTester tester, Widget campo) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: crearTemaUbb(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: campo,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('muestra el dato legible y sin candado, sin dejar editarlo',
      (tester) async {
    await _montar(
      tester,
      const CampoSoloLectura(
        decoracion: InputDecoration(labelText: 'Marca'),
        valor: 'Trek',
      ),
    );

    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.readOnly, isTrue);
    expect(campo.enabled ?? true, isTrue);
    expect(campo.canRequestFocus, isFalse);
    expect(campo.decoration?.fillColor, ColoresUbb.fondo);
    expect(find.text('Marca'), findsOneWidget);
    expect(find.text('Trek'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    await tester.tap(find.text('Trek'));
    await tester.pump();

    expect(tester.testTextInput.hasAnyClients, isFalse);
  });

  testWidgets('sin dato muestra el texto de respaldo', (tester) async {
    await _montar(
      tester,
      const CampoSoloLectura(
        decoracion: InputDecoration(labelText: 'Aro'),
        valor: '',
        textoVacio: 'Sin aro',
      ),
    );

    expect(find.text('Aro'), findsOneWidget);
    expect(find.text('Sin aro'), findsOneWidget);
  });

  testWidgets('se actualiza con el controlador y con un valor nuevo',
      (tester) async {
    final controlador = TextEditingController(text: 'Roja');
    addTearDown(controlador.dispose);
    await _montar(
      tester,
      CampoSoloLectura(
        decoracion: const InputDecoration(labelText: 'Color'),
        controlador: controlador,
      ),
    );
    expect(find.text('Roja'), findsOneWidget);

    controlador.text = 'Azul';
    await tester.pump();
    expect(find.text('Azul'), findsOneWidget);

    await _montar(
      tester,
      const CampoSoloLectura(
        decoracion: InputDecoration(labelText: 'Estado'),
        valor: 'Activa',
      ),
    );
    await _montar(
      tester,
      const CampoSoloLectura(
        decoracion: InputDecoration(labelText: 'Estado'),
        valor: 'Inactiva',
      ),
    );
    expect(find.text('Inactiva'), findsOneWidget);
    expect(find.text('Activa'), findsNothing);
  });
}
