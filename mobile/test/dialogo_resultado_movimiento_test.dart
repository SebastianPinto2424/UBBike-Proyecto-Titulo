import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/acceso/presentation/dialogo_resultado_movimiento.dart';

Future<void> _avisar(
  WidgetTester tester, {
  required bool confirmado,
  required bool esIngreso,
  VoidCallback? alTerminar,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: crearTemaUbb(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => avisarMovimientoRegistrado(
              context,
              confirmado: confirmado,
              esIngreso: esIngreso,
              persona: 'Ana Pérez',
              alTerminar: alTerminar,
            ),
            child: const Text('registrar'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('registrar'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('muestra el registro, se cierra solo y lleva al historial',
      (tester) async {
    var historial = 0;
    await _avisar(
      tester,
      confirmado: true,
      esIngreso: true,
      alTerminar: () => historial++,
    );

    expect(find.text('Ingreso registrado'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Abriendo el historial…'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(historial, 0);

    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    expect(find.text('Ingreso registrado'), findsNothing);
    expect(historial, 1);
  });

  testWidgets('el rechazo usa su propio ícono y título', (tester) async {
    await _avisar(tester, confirmado: false, esIngreso: false);

    expect(find.text('Retiro rechazado'), findsOneWidget);
    expect(find.byIcon(Icons.block), findsOneWidget);
    expect(find.text('Abriendo el historial…'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
  });
}
