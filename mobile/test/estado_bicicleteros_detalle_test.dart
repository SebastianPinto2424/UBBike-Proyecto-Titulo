import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/shared/widgets/panel_operativo_widgets.dart';

void main() {
  testWidgets('sin destino de bicicleteros el boton Ver detalle no se muestra',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: crearTemaUbb(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: EstadoBicicleterosOperativo(bicicleteros: []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Estado de bicicleteros'), findsOneWidget);
    expect(find.text('Ver detalle'), findsNothing);
  });

  testWidgets('Ver detalle dispara el destino de bicicleteros', (tester) async {
    var abierto = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: crearTemaUbb(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: EstadoBicicleterosOperativo(
              bicicleteros: const [],
              onVerDetalle: () => abierto++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();

    expect(abierto, 1);
  });
}
