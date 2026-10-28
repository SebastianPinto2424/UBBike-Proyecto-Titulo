import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/incidencias/data/borrador_incidencia.dart';
import 'package:ubbike/features/incidencias/presentation/hoja_registrar_incidencia.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

const _foto =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

const _bicicleteros = [
  BicicleteroApp(
    id: 'bicicletero-1',
    nombre: 'Bicicletero FACE',
    ubicacion: 'Sector FACE',
    capacidad: 20,
    ocupados: 5,
    cuposDisponibles: 15,
    porcentajeUso: 25,
  ),
  BicicleteroApp(
    id: 'bicicletero-2',
    nombre: 'Bicicletero Idiomas',
    ubicacion: 'Centro de Idiomas',
    capacidad: 20,
    ocupados: 0,
    cuposDisponibles: 20,
    porcentajeUso: 0,
  ),
];

const _borrador = BorradorIncidencia(
  bicicleteroId: 'bicicletero-2',
  bicicletaId: null,
  tipo: 'DANO_INFRAESTRUCTURA',
  descripcion: 'Candado roto en la entrada',
  fotos: [_foto],
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('el borrador se guarda y se toma una sola vez', () async {
    expect(await existeBorradorIncidencia(), isFalse);

    await guardarBorradorIncidencia(_borrador);
    expect(await existeBorradorIncidencia(), isTrue);

    final tomado = await tomarBorradorIncidencia();
    expect(tomado?.bicicleteroId, 'bicicletero-2');
    expect(tomado?.descripcion, 'Candado roto en la entrada');
    expect(tomado?.fotos, [_foto]);

    expect(await existeBorradorIncidencia(), isFalse);
    expect(await tomarBorradorIncidencia(), isNull);
  });

  testWidgets(
      'al volver tras cerrarse la app, el formulario recupera los datos y '
      'las fotos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: crearTemaUbb(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HojaRegistrarIncidencia(
              bicicleteros: _bicicleteros,
              bicicletas: const [],
              permitirBicicletaPropia: false,
              borrador: _borrador,
              onEnviar: ({
                required bicicleteroId,
                required tipo,
                required descripcion,
                bicicletaId,
                fotos = const [],
              }) async =>
                  null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Recuperamos el reporte que estabas completando cuando '
          'se cerró la app.'),
      findsOneWidget,
    );
    expect(find.text('Bicicletero Idiomas'), findsOneWidget);
    expect(find.text('Candado roto en la entrada'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });
}
