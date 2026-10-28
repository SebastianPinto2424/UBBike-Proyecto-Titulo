import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';

void main() {
  testWidgets('renderiza un widget basico de UBBike', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: crearTemaUbb(),
        home: const Scaffold(
          body: Center(
            child: ChipEstado(
              texto: 'Activa',
              color: ColoresUbb.exito,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Activa'), findsOneWidget);
  });
}
