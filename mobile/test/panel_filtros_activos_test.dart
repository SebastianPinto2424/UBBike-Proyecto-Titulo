import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';

Widget _envoltorio(Widget hijo) {
  return MaterialApp(
    theme: crearTemaUbb(),
    home: Scaffold(
      body: SingleChildScrollView(child: hijo),
    ),
  );
}

void main() {
  testWidgets('sin filtros activos el panel no muestra chips ni contador',
      (tester) async {
    await tester.pumpWidget(
      _envoltorio(
        const PanelFiltros(
          titulo: 'Filtros',
          detalle: 'Semana | Todos',
          children: [SizedBox(height: 20)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InputChip), findsNothing);
    expect(find.text('1'), findsNothing);
    expect(find.text('Filtros'), findsOneWidget);
  });

  testWidgets('los filtros activos aparecen como chips con su contador',
      (tester) async {
    await tester.pumpWidget(
      _envoltorio(
        PanelFiltros(
          titulo: 'Filtros',
          detalle: 'Mes | Ingresos',
          activos: [
            FiltroActivo(etiqueta: 'Mes', onQuitar: () {}),
            FiltroActivo(etiqueta: 'Ingresos', onQuitar: () {}),
          ],
          children: const [SizedBox(height: 20)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InputChip), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('los chips se ven con el panel cerrado y llaman a onQuitar',
      (tester) async {
    var quitado = 0;

    await tester.pumpWidget(
      _envoltorio(
        PanelFiltros(
          titulo: 'Filtros',
          detalle: 'Un filtro aplicado',
          activos: [
            FiltroActivo(etiqueta: 'Mes', onQuitar: () => quitado++),
          ],
          children: const [SizedBox(height: 20)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(quitado, 1);
  });

  testWidgets('muchos chips no desbordan en pantalla angosta', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _envoltorio(
        PanelFiltros(
          titulo: 'Filtros de operaciones',
          detalle: 'Varios filtros aplicados',
          activos: [
            for (final etiqueta in const [
              'Mes',
              'Ingresos',
              'Confirmados',
              'Bicicletero cercano a la FACE, El Boldo',
              'Valentina Antonia Soto Riquelme',
              'Busca: bicicleta roja',
            ])
              FiltroActivo(etiqueta: etiqueta, onQuitar: () {}),
          ],
          children: const [SizedBox(height: 20)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(InputChip), findsNWidgets(6));
    expect(find.text('6'), findsOneWidget);
  });
}
