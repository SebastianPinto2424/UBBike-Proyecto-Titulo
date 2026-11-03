import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/features/autenticacion/presentation/pantalla_inicio_sesion.dart';

import 'soporte_api_falsa.dart';

Finder _campoCorreo() =>
    find.widgetWithText(TextFormField, 'Correo electrónico');

Future<void> _montar(WidgetTester tester, {String? mensaje}) => montarConApi(
      tester,
      PantallaInicioSesion(mensajeInicial: mensaje),
      conScaffold: false,
      rutas: const {},
    );

Finder _aviso(String mensaje) => find.descendant(
      of: find.byType(SnackBar),
      matching: find.text(mensaje),
    );

void main() {
  testWidgets(
      'el motivo del cierre sale en un aviso que no mueve el formulario',
      (tester) async {
    await _montar(tester);
    final posicionSinAviso = tester.getTopLeft(_campoCorreo());

    await _montar(tester, mensaje: mensajeCuentaEliminada);

    expect(_aviso(mensajeCuentaEliminada), findsOneWidget);
    expect(tester.getTopLeft(_campoCorreo()), posicionSinAviso);
  });

  testWidgets('el aviso desaparece solo a los pocos segundos', (tester) async {
    await _montar(tester, mensaje: mensajeSesionEnOtroDispositivo);
    expect(_aviso(mensajeSesionEnOtroDispositivo), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();

    expect(find.text(mensajeSesionEnOtroDispositivo), findsNothing);
  });

  testWidgets('el aviso se puede cerrar antes con la equis', (tester) async {
    await _montar(tester, mensaje: mensajeContrasenaActualizada);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text(mensajeContrasenaActualizada), findsNothing);
  });

  testWidgets('sin motivo no aparece ningún aviso', (tester) async {
    await _montar(tester);

    expect(find.byType(SnackBar), findsNothing);
  });
}
