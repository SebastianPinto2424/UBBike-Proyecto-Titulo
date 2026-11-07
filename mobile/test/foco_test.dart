import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/shared/utilidades/foco.dart';

Future<FocusNode> _montarCampo(WidgetTester tester) async {
  final foco = FocusNode();
  addTearDown(foco.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: TextField(focusNode: foco)),
    ),
  );
  return foco;
}

void main() {
  testWidgets('soltar el foco cierra el teclado del campo activo',
      (tester) async {
    final foco = await _montarCampo(tester);
    await tester.showKeyboard(find.byType(TextField));
    expect(foco.hasFocus, isTrue);

    soltarFoco();
    await tester.pump();

    expect(foco.hasFocus, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);
  });

  testWidgets('enfocar al dibujar espera el cuadro y enfoca el campo',
      (tester) async {
    final foco = await _montarCampo(tester);

    enfocarAlDibujar(foco);
    expect(foco.hasFocus, isFalse);
    await tester.pump();

    expect(foco.hasFocus, isTrue);
  });

  testWidgets('enfocar al dibujar ignora un campo que ya no está en pantalla',
      (tester) async {
    final foco = await _montarCampo(tester);

    enfocarAlDibujar(foco);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    expect(foco.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
  });
}
