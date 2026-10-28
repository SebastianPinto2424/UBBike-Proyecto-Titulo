import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/acceso/presentation/dialogo_nota_cierre.dart';
import 'package:ubbike/shared/utilidades/revision_ortografica.dart';

void main() {
  testWidgets('sin corrector del sistema no se activa la revision',
      (tester) async {
    tester.platformDispatcher.nativeSpellCheckServiceDefinedTestValue = false;
    addTearDown(tester.platformDispatcher.clearNativeSpellCheckServiceDefined);

    expect(revisionOrtografica(), isNull);
  });

  testWidgets('los campos de texto libre marcan las faltas de ortografia',
      (tester) async {
    tester.platformDispatcher.nativeSpellCheckServiceDefinedTestValue = true;
    addTearDown(tester.platformDispatcher.clearNativeSpellCheckServiceDefined);

    await tester.pumpWidget(
      MaterialApp(
        theme: crearTemaUbb(),
        home: const Scaffold(body: DialogoNotaCierre()),
      ),
    );

    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.spellCheckConfiguration, isNotNull);
    expect(campo.textCapitalization, TextCapitalization.sentences);
    expect(
      tester
          .state<EditableTextState>(find.byType(EditableText))
          .spellCheckEnabled,
      isTrue,
    );
  });
}
