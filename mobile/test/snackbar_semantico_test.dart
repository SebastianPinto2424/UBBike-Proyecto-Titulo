import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';

void main() {
  testWidgets('un aviso nuevo reemplaza al anterior en vez de hacer fila',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: crearTemaUbb(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                context.mostrarExito('Ingreso registrado');
                context.mostrarError('No se pudo enviar');
                context.mostrarInfo('Solicitud actualizada');
              },
              child: const Text('avisar'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('avisar'));
    await tester.pumpAndSettle();

    expect(find.text('Solicitud actualizada'), findsOneWidget);
    expect(find.text('Ingreso registrado'), findsNothing);
    expect(find.text('No se pudo enviar'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Ingreso registrado'), findsNothing);
    expect(find.text('No se pudo enviar'), findsNothing);
  });
}
