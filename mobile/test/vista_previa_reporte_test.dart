import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/shared/widgets/vista_previa_reporte.dart';

const _encabezados = ['Tipo', 'Estado', 'Usuario'];

List<List<String>> _filas(int cantidad) => List.generate(
    cantidad, (i) => ['Ingreso', 'Confirmado', 'Usuario ${i + 1}']);

Future<bool?> _abrir(
  WidgetTester tester, {
  required int total,
  required List<List<String>> filas,
  String formato = 'PDF',
  List<String> columnasAdicionales = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  bool? resultado;
  await tester.pumpWidget(MaterialApp(
    theme: crearTemaUbb(),
    home: Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () async {
                  resultado = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    useSafeArea: true,
                    builder: (_) => VistaPreviaReporte(
                      formato: formato,
                      encabezados: _encabezados,
                      filas: filas,
                      totalRegistros: total,
                      resumenFiltros: 'Mes · Todos',
                      columnasAdicionales: columnasAdicionales,
                    ),
                  );
                },
                child: const Text('Abrir')))),
  ));
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  return resultado;
}

void main() {
  testWidgets('muestra el formato, el total y los filtros aplicados',
      (tester) async {
    await _abrir(tester, total: 3, filas: _filas(3));

    expect(find.text('Vista previa · PDF'), findsOneWidget);
    expect(find.textContaining('3 registros'), findsOneWidget);
    expect(find.textContaining('Mes · Todos'), findsOneWidget);
    expect(find.text('Usuario 1'), findsOneWidget);
  });

  testWidgets('usa singular con un solo registro', (tester) async {
    await _abrir(tester, total: 1, filas: _filas(1));

    expect(find.textContaining('1 registro ·'), findsOneWidget);
  });

  testWidgets('limita la muestra a 20 filas y avisa cuántas faltan',
      (tester) async {
    await _abrir(tester, total: 142, filas: _filas(142));

    expect(find.text('Usuario 20'), findsOneWidget);
    expect(find.text('Usuario 21'), findsNothing);
    expect(find.textContaining('El archivo incluye 122 más'), findsOneWidget);
  });

  testWidgets('avisa de las columnas que solo trae el Excel', (tester) async {
    await _abrir(tester,
        total: 2,
        filas: _filas(2),
        formato: 'Excel',
        columnasAdicionales: ['Marca', 'Modelo']);

    expect(find.text('Vista previa · Excel'), findsOneWidget);
    expect(find.textContaining('Marca, Modelo'), findsOneWidget);
  });

  testWidgets('sin registros bloquea la descarga y explica por qué',
      (tester) async {
    await _abrir(tester, total: 0, filas: const []);

    expect(find.textContaining('No hay movimientos con estos filtros'),
        findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('previa-descargar')))
            .onPressed,
        isNull);
  });

  testWidgets('descargar confirma y cancelar no', (tester) async {
    await _abrir(tester, total: 2, filas: _filas(2));
    await tester.tap(find.byKey(const Key('previa-descargar')));
    await tester.pumpAndSettle();
    expect(find.byType(VistaPreviaReporte), findsNothing);

    await _abrir(tester, total: 2, filas: _filas(2));
    await tester.tap(find.byKey(const Key('previa-cancelar')));
    await tester.pumpAndSettle();
    expect(find.byType(VistaPreviaReporte), findsNothing);
  });

  for (final escala in [1.0, 1.8]) {
    testWidgets('sin desbordes con escala $escala', (tester) async {
      await _abrir(tester, total: 40, filas: _filas(40));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('el boton de confirmar refleja la accion elegida',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VistaPreviaReporte(
            formato: 'PDF',
            encabezados: ['Tipo'],
            filas: [
              ['INGRESO'],
            ],
            totalRegistros: 1,
            resumenFiltros: 'Semana',
            textoConfirmar: 'Compartir',
            iconoConfirmar: Icons.ios_share,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Compartir'), findsOneWidget);
    expect(find.text('Descargar'), findsNothing);
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
  });
}
