import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/features/bicicletas/presentation/vista_bicicletas_usuario.dart';

import 'soporte_api_falsa.dart';

Map<String, dynamic> _bici({
  String id = 'b1',
  String descripcion = 'Urbana azul',
  bool activa = true,
  bool dentro = false,
  String? fotoUrl = '/uploads/bicicletas/b1.jpg',
}) =>
    {
      'id': id,
      'descripcion': descripcion,
      'marca': 'Oxford',
      'modelo': 'Venus',
      'color': 'Azul',
      'aro': '26',
      'numeroSerie': 'SN123',
      'fotoUrl': fotoUrl,
      'activa': activa,
      'dentroBicicletero': dentro,
      'bicicleteroActual': dentro ? {'id': 'r1', 'nombre': 'Biblioteca'} : null,
    };

Future<ApiFalsa> _montar(
  WidgetTester tester,
  List<Map<String, dynamic>> bicicletas, {
  Map<String, Object?> extra = const {},
}) =>
    montarConApi(
      tester,
      const VistaBicicletas(vistaMovimientos: Text('movimientos')),
      rutas: {
        'GET /bicicletas': {'bicicletas': bicicletas},
        ...extra,
      },
    );

Future<void> _abrirGestion(WidgetTester tester, {int indice = 0}) async {
  await tocar(tester, find.text('Gestionar bicicleta').at(indice));
}

void main() {
  testWidgets('sin bicicletas invita a registrar la primera', (tester) async {
    await _montar(tester, []);

    expect(find.text('Sin bicicletas'), findsOneWidget);
    expect(find.text('Registrar bicicleta'), findsOneWidget);
  });

  testWidgets('si el backend falla ofrece reintentar', (tester) async {
    await montarConApi(
      tester,
      const VistaBicicletas(vistaMovimientos: SizedBox()),
      rutas: {'GET /bicicletas': const RespuestaFalsa(500)},
    );

    expect(find.text('No se pudieron cargar bicicletas'), findsOneWidget);
  });

  testWidgets('muestra estado, ubicación y ficha de cada bicicleta',
      (tester) async {
    await _montar(tester, [
      _bici(dentro: true),
      _bici(id: 'b2', descripcion: 'Montaña roja', activa: false),
    ]);

    expect(find.text('Urbana azul'), findsOneWidget);
    expect(find.text('Montaña roja'), findsOneWidget);
    expect(find.text('Activa'), findsWidgets);
    expect(find.text('Inactiva'), findsWidgets);
    expect(find.text('Dentro - Biblioteca'), findsOneWidget);
    expect(find.text('Fuera del bicicletero'), findsOneWidget);
  });

  testWidgets('activar otra bicicleta llama al backend y avisa',
      (tester) async {
    final api = await _montar(
      tester,
      [
        _bici(),
        _bici(id: 'b2', descripcion: 'Montaña roja', activa: false),
      ],
      extra: {'PATCH /bicicletas/b2/activar': const {}},
    );

    await _abrirGestion(tester, indice: 1);
    await tocar(tester, find.byType(Switch).last);

    expect(api.llamadas, contains('PATCH /bicicletas/b2/activar'));
    expect(find.text('Montaña roja activada'), findsOneWidget);
  });

  testWidgets('desactivar la activa usa su ruta propia', (tester) async {
    final api = await _montar(
      tester,
      [_bici()],
      extra: {'PATCH /bicicletas/b1/desactivar': const {}},
    );

    await _abrirGestion(tester);
    await tocar(tester, find.byType(Switch).last);

    expect(api.llamadas, contains('PATCH /bicicletas/b1/desactivar'));
    expect(find.text('Urbana azul inactiva'), findsOneWidget);
  });

  testWidgets('eliminar pide confirmación antes de borrar', (tester) async {
    final api = await _montar(
      tester,
      [_bici()],
      extra: {'DELETE /bicicletas/b1': const {}},
    );

    await _abrirGestion(tester);
    await tocarTexto(tester, 'Eliminar');
    expect(find.text('Eliminar bicicleta'), findsOneWidget);

    await tester.tap(find.byKey(const Key('eliminar-cancelar')));
    await tester.pumpAndSettle();
    expect(api.llamadas, isNot(contains('DELETE /bicicletas/b1')));

    await tocarTexto(tester, 'Eliminar');
    await tester.tap(find.byKey(const Key('eliminar-confirmar')));
    await tester.pumpAndSettle();

    expect(api.llamadas, contains('DELETE /bicicletas/b1'));
    expect(find.text('Bicicleta eliminada'), findsOneWidget);
  });

  testWidgets('si no se puede eliminar muestra el motivo', (tester) async {
    await _montar(
      tester,
      [_bici(dentro: true)],
      extra: {
        'DELETE /bicicletas/b1': const RespuestaFalsa(409, {
          'message':
              'No puedes eliminar una bicicleta que está dentro de un bicicletero. Registra primero su retiro.',
        }),
      },
    );

    await _abrirGestion(tester);
    await tocarTexto(tester, 'Eliminar');
    await tester.tap(find.byKey(const Key('eliminar-confirmar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Registra primero su retiro'), findsOneWidget);
  });

  testWidgets('editar guarda los cambios y recarga la lista', (tester) async {
    final api = await _montar(
      tester,
      [_bici()],
      extra: {'PATCH /bicicletas/b1': const {}},
    );

    await _abrirGestion(tester);
    await tocarTexto(tester, 'Editar');
    expect(find.text('Editar bicicleta'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Urbana celeste',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Número de serie'),
      'sn999',
    );
    await tocarTexto(tester, 'Guardar');

    final cuerpo = api.cuerpoDe('PATCH /bicicletas/b1');
    expect(cuerpo['descripcion'], 'Urbana celeste');
    expect(cuerpo['numeroSerie'], 'SN999');
    expect(find.text('Datos editados correctamente'), findsOneWidget);
    expect(
      api.llamadas.where((l) => l == 'GET /bicicletas').length,
      greaterThanOrEqualTo(2),
    );
  });

  testWidgets('el formulario muestra el error del backend', (tester) async {
    await _montar(
      tester,
      [_bici()],
      extra: {
        'PATCH /bicicletas/b1': const RespuestaFalsa(
          409,
          {'message': 'Ya existe una bicicleta con ese número de serie'},
        ),
      },
    );

    await _abrirGestion(tester);
    await tocarTexto(tester, 'Editar');
    await tocarTexto(tester, 'Guardar');

    expect(
      find.textContaining('número de serie'),
      findsWidgets,
    );
    expect(find.text('Editar bicicleta'), findsOneWidget);
  });

  testWidgets('registrar una nueva exige descripción y foto', (tester) async {
    final api = await _montar(tester, [_bici()]);

    await tocarTexto(tester, 'Registrar');
    expect(find.text('Registrar bicicleta'), findsWidgets);

    await tocarTexto(tester, 'Guardar');

    expect(find.text('Toma o sube una foto.'), findsOneWidget);
    expect(api.llamadas, isNot(contains('POST /bicicletas')));
  });
}
