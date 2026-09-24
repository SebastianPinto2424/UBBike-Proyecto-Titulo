import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';

import 'package:ubbike/shared/widgets/lista_con_filtros.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';

Widget _pantalla({required int elementos}) {
  return MaterialApp(
    theme: crearTemaUbb(),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ListaConFiltros(
          onRefrescar: () async {},
          cabecera: [
            const Text('Historial'),
            const SizedBox(height: 10),
            const TextField(
              decoration: InputDecoration(labelText: 'Buscar'),
            ),
            const SizedBox(height: 10),
            PanelFiltros(
              titulo: 'Filtros',
              detalle: 'Mes | Todos',
              onLimpiar: () {},
              children: [
                for (final etiqueta in const [
                  'Periodo',
                  'Tipo',
                  'Resultado',
                  'Origen',
                  'Bicicletero',
                  'Guardia',
                ])
                  EtiquetaFiltro(
                    texto: etiqueta,
                    child: const SizedBox(height: 56),
                  ),
              ],
            ),
          ],
          contenido: SliverList.list(
            children: [
              for (var i = 0; i < elementos; i++)
                SizedBox(height: 90, child: Text('Movimiento $i')),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'los filtros expandidos siguen siendo alcanzables en pantalla baja',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_pantalla(elementos: 25));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    expect(find.text('Periodo'), findsOneWidget);

    final desplazable = find.byType(CustomScrollView);
    await tester.drag(desplazable, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Guardia'), findsOneWidget);
    expect(find.text('Restablecer filtros'), findsOneWidget);
  });

  testWidgets('la lista se alcanza aunque los filtros esten abiertos',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_pantalla(elementos: 25));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Movimiento 0'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Movimiento 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el estado vacio ocupa el espacio restante sin desbordar',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_pantalla(elementos: 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
