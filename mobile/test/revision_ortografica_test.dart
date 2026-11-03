import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/servicios/corrector_ortografico_servicio.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/acceso/presentation/dialogo_nota_cierre.dart';
import 'package:ubbike/shared/utilidades/revision_ortografica.dart';

Future<void> _montarNotaCierre(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        theme: crearTemaUbb(),
        home: const Scaffold(body: DialogoNotaCierre()),
      ),
    );

bool _revisionActiva(WidgetTester tester) => tester
    .state<EditableTextState>(find.byType(EditableText))
    .spellCheckEnabled;

void main() {
  testWidgets('con corrector del teléfono se usa ese', (tester) async {
    tester.platformDispatcher.nativeSpellCheckServiceDefinedTestValue = true;
    addTearDown(tester.platformDispatcher.clearNativeSpellCheckServiceDefined);

    expect(revisionOrtografica().spellCheckService, isNull);
  });

  testWidgets('sin corrector del teléfono se usa el diccionario de la app',
      (tester) async {
    tester.platformDispatcher.nativeSpellCheckServiceDefinedTestValue = false;
    addTearDown(tester.platformDispatcher.clearNativeSpellCheckServiceDefined);

    expect(revisionOrtografica().spellCheckService,
        same(CorrectorOrtograficoServicio.instancia));
  });

  testWidgets('los campos de texto libre marcan las faltas de ortografía',
      (tester) async {
    tester.platformDispatcher.nativeSpellCheckServiceDefinedTestValue = true;
    addTearDown(tester.platformDispatcher.clearNativeSpellCheckServiceDefined);

    await _montarNotaCierre(tester);

    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.spellCheckConfiguration, isNotNull);
    expect(campo.textCapitalization, TextCapitalization.sentences);
    expect(_revisionActiva(tester), isTrue);
  });

  testWidgets('sin corrector del teléfono los campos también revisan',
      (tester) async {
    tester.platformDispatcher.nativeSpellCheckServiceDefinedTestValue = false;
    addTearDown(tester.platformDispatcher.clearNativeSpellCheckServiceDefined);

    await _montarNotaCierre(tester);

    expect(_revisionActiva(tester), isTrue);
  });
}
