import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/app/principal/vista_soporte.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/features/acceso/presentation/vista_guardias_en_turno.dart';
import 'package:ubbike/features/inicio/presentation/resumen_guardias_en_turno.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/widgets/selector_desplegable.dart';

import 'soporte_api_falsa.dart';

const _nombreLargo =
    'Facultad de Ciencias Empresariales y Administración Pública';

Map<String, dynamic> _rack(
  String id,
  String nombre, {
  String? guardia,
  String guardiaId = 'g1',
  int cupos = 15,
}) =>
    {
      'id': id,
      'nombre': nombre,
      'ubicacion': 'Campus',
      'capacidad': 20,
      'ocupados': 20 - cupos,
      'cuposDisponibles': cupos,
      'porcentajeUso': (20 - cupos) * 5,
      if (guardia != null)
        'guardiaActivo': {'id': guardiaId, 'nombre': guardia},
    };

Map<String, dynamic> _bicicleteros({
  bool conGuardiaEnBiblioteca = true,
  bool conGuardiaEnIngenieria = false,
  bool conGuardiaEnEmpresariales = false,
}) =>
    {
      'bicicleteros': [
        _rack(
          'r1',
          'Biblioteca Central',
          guardia: conGuardiaEnBiblioteca ? 'Pedro Soto' : null,
        ),
        _rack(
          'r2',
          'Facultad de Ingeniería',
          guardia: conGuardiaEnIngenieria ? 'Juan Díaz' : null,
          guardiaId: 'g3',
        ),
        _rack(
          'r3',
          _nombreLargo,
          cupos: 1,
          guardia: conGuardiaEnEmpresariales ? 'Luis Paz' : null,
          guardiaId: 'g4',
        ),
      ],
    };

const _guardias = {
  'guardias': [
    {
      'id': 'g1',
      'nombre': 'Pedro Soto',
      'bicicletero': {'id': 'r1', 'nombre': 'Biblioteca Central'},
    },
    {'id': 'g2', 'nombre': 'Ana Rojas', 'bicicletero': null},
  ],
};

Future<ApiFalsa> _montar(
  WidgetTester tester, {
  Map<String, Object?> rutas = const {},
  RolUsuario rol = RolUsuario.adminCentral,
}) =>
    montarConApi(
      tester,
      const VistaGuardiasEnTurno(),
      rol: rol,
      rutas: {
        'GET /bicicleteros': _bicicleteros(),
        'GET /guardias': _guardias,
        ...rutas,
      },
    );

Finder get _botonAsignar => find.ancestor(
      of: find.text('Asignar guardia'),
      matching: find.byWidgetPredicate((widget) => widget is ElevatedButton),
    );

Finder _enLista(String texto) =>
    find.descendant(of: find.byType(Card), matching: find.text(texto));

Finder _opcion(String texto) => find.descendant(
      of: find.byType(OpcionDesplegable),
      matching: find.text(texto),
    );

Future<void> _elegirBicicletero(WidgetTester tester, String nombre) async {
  await tocarTexto(tester, 'Selecciona un bicicletero');
  await tocar(tester, _opcion(nombre));
}

Future<void> _elegirGuardia(WidgetTester tester, String nombre) async {
  await tocarTexto(tester, 'Selecciona un guardia');
  await tocar(tester, _opcion(nombre));
}

void main() {
  group('asignar guardia', () {
    testWidgets('el selector solo ofrece bicicleteros sin guardia',
        (tester) async {
      await _montar(tester);

      await tocarTexto(tester, 'Selecciona un bicicletero');

      expect(_opcion('Biblioteca Central'), findsNothing);
      expect(_opcion('Facultad de Ingeniería'), findsOneWidget);
      expect(_opcion(_nombreLargo), findsOneWidget);
      expect(find.text('1 cupo disponible'), findsOneWidget);
      expect(tester.widget<Text>(_opcion(_nombreLargo)).maxLines, isNull);
    });

    testWidgets('el botón se habilita con bicicletero y guardia elegidos',
        (tester) async {
      await _montar(tester);
      bool habilitado() =>
          tester.widget<ElevatedButton>(_botonAsignar).onPressed != null;

      expect(habilitado(), isFalse);
      await _elegirBicicletero(tester, _nombreLargo);
      expect(habilitado(), isFalse);
      await _elegirGuardia(tester, 'Ana Rojas');

      expect(habilitado(), isTrue);
      expect(find.text(_nombreLargo), findsWidgets);
    });

    testWidgets('asigna un guardia libre y limpia el formulario',
        (tester) async {
      final api = await _montar(
        tester,
        rutas: {
          'POST /bicicleteros/r2/guardia': {
            'asignacion': {'id': 'a1'}
          },
        },
      );

      await _elegirBicicletero(tester, 'Facultad de Ingeniería');
      await _elegirGuardia(tester, 'Ana Rojas');
      await tocar(tester, _botonAsignar);

      expect(
          api.cuerpoDe('POST /bicicleteros/r2/guardia'), {'guardiaId': 'g2'});
      expect(find.text('Ana Rojas ahora gestiona Facultad de Ingeniería'),
          findsOneWidget);
      expect(find.text('Selecciona un bicicletero'), findsOneWidget);
      expect(
        api.llamadas.where((llamada) => llamada == 'GET /bicicleteros'),
        hasLength(2),
      );
    });

    testWidgets('pide confirmar antes de trasladar a un guardia en turno',
        (tester) async {
      final api = await _montar(
        tester,
        rutas: {
          'POST /bicicleteros/r2/guardia': {
            'asignacion': {'id': 'a2'}
          },
        },
      );

      await _elegirBicicletero(tester, 'Facultad de Ingeniería');
      await tocarTexto(tester, 'Selecciona un guardia');
      expect(find.text('En Biblioteca Central'), findsOneWidget);
      await tocar(tester, _opcion('Pedro Soto'));
      await tocar(tester, _botonAsignar);

      expect(find.text('Trasladar guardia'), findsOneWidget);
      expect(
        find.textContaining(
            'Dejará Biblioteca Central y pasará a Facultad de Ingeniería'),
        findsOneWidget,
      );
      await tocarTexto(tester, 'Trasladar');

      expect(
          api.cuerpoDe('POST /bicicleteros/r2/guardia'), {'guardiaId': 'g1'});
    });

    testWidgets('si se cancela el traslado no asigna nada', (tester) async {
      final api = await _montar(tester);

      await _elegirBicicletero(tester, 'Facultad de Ingeniería');
      await _elegirGuardia(tester, 'Pedro Soto');
      await tocar(tester, _botonAsignar);
      await tocarTexto(tester, 'Cancelar');

      expect(api.llamadas, isNot(contains('POST /bicicleteros/r2/guardia')));
      expect(find.text('Pedro Soto · En Biblioteca Central'), findsOneWidget);
    });

    testWidgets('si el servidor rechaza la asignación muestra el motivo',
        (tester) async {
      await _montar(
        tester,
        rutas: {
          'POST /bicicleteros/r2/guardia': const RespuestaFalsa(409, {
            'message':
                'Juan Díaz ya gestiona Facultad de Ingeniería. Libéralo antes de asignar a otro guardia.'
          }),
        },
      );

      await _elegirBicicletero(tester, 'Facultad de Ingeniería');
      await _elegirGuardia(tester, 'Ana Rojas');
      await tocar(tester, _botonAsignar);

      expect(find.textContaining('Juan Díaz ya gestiona'), findsOneWidget);
    });

    testWidgets(
        'si otro guardia toma el bicicletero elegido lo quita al instante',
        (tester) async {
      final api = await _montar(tester);

      await _elegirBicicletero(tester, 'Facultad de Ingeniería');
      api.responder(
        'GET /bicicleteros',
        _bicicleteros(conGuardiaEnIngenieria: true),
      );
      ProviderScope.containerOf(
        tester.element(find.byType(VistaGuardiasEnTurno)),
      ).read(bicicleterosVersionProvider.notifier).state++;
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Facultad de Ingeniería ya tiene guardia. Elige otro bicicletero.'),
        findsOneWidget,
      );
      expect(find.text('Selecciona un bicicletero'), findsOneWidget);
      expect(find.text('2 de 3 bicicleteros con guardia'), findsOneWidget);
      expect(_enLista('Juan Díaz'), findsOneWidget);
    });

    testWidgets('se actualiza sola aunque se pierda un aviso en tiempo real',
        (tester) async {
      final api = await _montar(tester);
      api.responder(
        'GET /bicicleteros',
        _bicicleteros(conGuardiaEnIngenieria: true),
      );

      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(find.text('2 de 3 bicicleteros con guardia'), findsOneWidget);
      expect(_enLista('Juan Díaz'), findsOneWidget);
    });

    testWidgets('cuando todos tienen guardia lo indica', (tester) async {
      await _montar(
        tester,
        rutas: {
          'GET /bicicleteros': _bicicleteros(
            conGuardiaEnIngenieria: true,
            conGuardiaEnEmpresariales: true,
          ),
        },
      );

      expect(
          find.text('Todos los bicicleteros tienen guardia'), findsOneWidget);
      expect(find.text('3 de 3 bicicleteros con guardia'), findsOneWidget);
    });

    testWidgets('sin guardias habilitados lo indica', (tester) async {
      await _montar(
        tester,
        rutas: {
          'GET /guardias': {'guardias': []},
        },
      );

      expect(find.text('No hay guardias habilitados'), findsOneWidget);
    });
  });

  group('guardias en turno', () {
    testWidgets('lista quién gestiona cada bicicletero con su nombre completo',
        (tester) async {
      await _montar(tester);

      expect(find.text('1 de 3 bicicleteros con guardia'), findsOneWidget);
      expect(_enLista('Biblioteca Central'), findsOneWidget);
      expect(_enLista('Pedro Soto'), findsOneWidget);
      expect(_enLista('Facultad de Ingeniería'), findsNothing);
      expect(
          tester.widget<Text>(_enLista('Biblioteca Central')).maxLines, isNull);
    });

    testWidgets('libera un bicicletero después de confirmar y recarga',
        (tester) async {
      final api = await _montar(
        tester,
        rutas: {
          'DELETE /bicicleteros/r1/guardia': {
            'message': 'Bicicletero liberado'
          },
        },
      );
      api.responder(
        'GET /bicicleteros',
        _bicicleteros(conGuardiaEnBiblioteca: false),
      );

      await tocarTexto(tester, 'Liberar');
      expect(find.textContaining('Pedro Soto dejará de gestionarlo'),
          findsOneWidget);
      await tocar(tester, find.text('Liberar').last);

      expect(api.llamadas, contains('DELETE /bicicleteros/r1/guardia'));
      expect(find.text('Bicicletero liberado'), findsOneWidget);
      expect(find.text('0 de 3 bicicleteros con guardia'), findsOneWidget);
      expect(find.text('Ningún bicicletero tiene guardia'), findsOneWidget);
    });

    testWidgets('si se cancela la confirmación no libera nada', (tester) async {
      final api = await _montar(tester, rol: RolUsuario.administrador);

      await tocarTexto(tester, 'Liberar');
      await tocarTexto(tester, 'Cancelar');

      expect(api.llamadas, isNot(contains('DELETE /bicicleteros/r1/guardia')));
    });

    testWidgets('si el servidor rechaza la liberación muestra el motivo',
        (tester) async {
      await _montar(
        tester,
        rutas: {
          'DELETE /bicicleteros/r1/guardia': const RespuestaFalsa(
              409, {'message': 'Pedro Soto ya dejó Biblioteca Central'}),
        },
      );

      await tocarTexto(tester, 'Liberar');
      await tocar(tester, find.text('Liberar').last);

      expect(
          find.text('Pedro Soto ya dejó Biblioteca Central'), findsOneWidget);
    });

    testWidgets('si falla la carga permite reintentar', (tester) async {
      final api = await _montar(
        tester,
        rutas: {
          'GET /bicicleteros': const RespuestaFalsa(500, {'message': 'Error'}),
        },
      );

      expect(find.text('No se pudo cargar la información'), findsOneWidget);

      api.responder('GET /bicicleteros', _bicicleteros());
      await tocarTexto(tester, 'Reintentar');

      expect(find.text('1 de 3 bicicleteros con guardia'), findsOneWidget);
    });
  });

  testWidgets('la sección guardias separa los turnos de las operaciones',
      (tester) async {
    await montarConApi(
      tester,
      const VistaGuardias(),
      rol: RolUsuario.adminCentral,
      rutas: {
        'GET /bicicleteros': _bicicleteros(),
        'GET /guardias': _guardias,
        'GET /historial': {'movimientos': []},
        'GET /historial/opciones': {'bicicleteros': [], 'guardias': []},
      },
    );

    expect(find.text('En turno'), findsOneWidget);
    expect(find.text('Operaciones'), findsOneWidget);
    expect(find.text('1 de 3 bicicleteros con guardia'), findsOneWidget);

    await tocarTexto(tester, 'Operaciones');

    expect(find.text('Sin operaciones'), findsOneWidget);
  });

  testWidgets('el resumen del inicio cuenta los bicicleteros sin guardia',
      (tester) async {
    var abierto = false;
    final bicicleteros = [
      for (final rack in _bicicleteros()['bicicleteros'] as List)
        BicicleteroApp.desdeJson(rack as Map<String, dynamic>),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResumenGuardiasEnTurno(
            bicicleteros: bicicleteros,
            onGestionar: () => abierto = true,
          ),
        ),
      ),
    );

    expect(find.text('1 de 3 bicicleteros con guardia'), findsOneWidget);
    expect(find.text('2 sin guardia'), findsOneWidget);

    await tester.tap(find.text('Gestionar'));

    expect(abierto, isTrue);
  });
}
