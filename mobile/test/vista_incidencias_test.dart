import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/features/incidencias/presentation/vista_incidencias.dart';

import 'soporte_api_falsa.dart';

Map<String, dynamic> _incidencia({
  String id = 'i1',
  String estado = 'PENDIENTE',
  bool puedeRecordar = true,
}) =>
    {
      'id': id,
      'tipo': 'DANO_INFRAESTRUCTURA',
      'descripcion': 'El soporte del bicicletero está suelto',
      'estado': estado,
      'creadaEn': '2026-10-20T13:30:00.000Z',
      'actualizadaEn': '2026-10-20T13:30:00.000Z',
      'recordatorios': 0,
      'puedeRecordar': puedeRecordar,
      'segundosParaRecordar': puedeRecordar ? 0 : 120,
      'bicicletero': {'id': 'r1', 'nombre': 'Biblioteca Central'},
      'reportadaPorUsuario': {
        'id': 'u1',
        'nombre': 'Ana Rojas',
        'correo': 'ana@alumnos.ubiobio.cl',
        'rol': 'ESTUDIANTE',
      },
      'fotos': const [],
    };

const _bicicleteros = {
  'bicicleteros': [
    {'id': 'r1', 'nombre': 'Biblioteca Central'},
  ],
};

Future<ApiFalsa> _montarUsuario(
  WidgetTester tester,
  Object? incidencias, {
  Map<String, Object?> extra = const {},
}) =>
    montarConApi(
      tester,
      const VistaIncidencias(mostrarReportante: false, puedeGestionar: false),
      rutas: {
        'GET /incidencias': incidencias,
        'GET /bicicleteros': _bicicleteros,
        ...extra,
      },
    );

Future<ApiFalsa> _montarCentral(
  WidgetTester tester, {
  Map<String, Object?> extra = const {},
}) =>
    montarConApi(
      tester,
      const VistaIncidencias(
        mostrarReportante: true,
        puedeGestionar: true,
        gestionCentral: true,
      ),
      rol: RolUsuario.adminCentral,
      rutas: {
        'GET /incidencias': {
          'incidencias': [_incidencia(puedeRecordar: false)],
          'nextCursor': null,
        },
        'GET /bicicleteros': _bicicleteros,
        ...extra,
      },
    );

Iterable<Map<String, String>> _consultas(ApiFalsa api) => api.peticiones
    .where((p) => p.method == 'GET' && p.url.path == '/incidencias')
    .map((p) => p.url.queryParameters);

void main() {
  testWidgets('sin reportes muestra el estado vacío', (tester) async {
    await _montarUsuario(tester, {'incidencias': [], 'nextCursor': null});

    expect(find.text('Sin incidencias'), findsOneWidget);
  });

  testWidgets('si falla la carga permite reintentar', (tester) async {
    final api = await _montarUsuario(tester, const RespuestaFalsa(500));

    expect(find.text('No se pudieron cargar incidencias'), findsOneWidget);

    api.responder('GET /incidencias', {
      'incidencias': [_incidencia()],
      'nextCursor': null,
    });
    await tocarTexto(tester, 'No se pudieron cargar incidencias');

    expect(find.text('El soporte del bicicletero está suelto'), findsOneWidget);
  });

  testWidgets('quien reportó puede enviar un recordatorio', (tester) async {
    final api = await _montarUsuario(
      tester,
      {
        'incidencias': [_incidencia()],
        'nextCursor': null,
      },
      extra: {
        'POST /incidencias/i1/recordar': {
          'incidencia': _incidencia(puedeRecordar: false),
        },
      },
    );

    await tocarTexto(tester, 'Recordar');

    expect(api.llamadas, contains('POST /incidencias/i1/recordar'));
    expect(find.text('Recordatorio enviado'), findsOneWidget);
  });

  testWidgets('si el recordatorio llega antes de tiempo muestra el motivo',
      (tester) async {
    await _montarUsuario(
      tester,
      {
        'incidencias': [_incidencia()],
        'nextCursor': null,
      },
      extra: {
        'POST /incidencias/i1/recordar': const RespuestaFalsa(409, {
          'message': 'Podrás recordar nuevamente en 200 segundos',
        }),
      },
    );

    await tocarTexto(tester, 'Recordar');

    expect(find.text('Podrás recordar nuevamente en 200 segundos'),
        findsOneWidget);
  });

  testWidgets('pagina con el cursor del backend', (tester) async {
    final api = await _montarUsuario(
      tester,
      (dynamic peticion) => peticion.url.queryParameters['cursor'] == 'c2'
          ? {
              'incidencias': [_incidencia(id: 'i2', estado: 'RESUELTA')],
              'nextCursor': null,
            }
          : {
              'incidencias': [_incidencia()],
              'nextCursor': 'c2',
            },
    );

    await tocarTexto(tester, 'Cargar más incidencias');

    expect(_consultas(api).last['cursor'], 'c2');
    expect(find.text('Resuelta'), findsWidgets);
  });

  testWidgets('filtrar por estado consulta al backend', (tester) async {
    final api =
        await _montarUsuario(tester, {'incidencias': [], 'nextCursor': null});

    await tocarTexto(tester, 'Filtros');
    await tocarTexto(tester, 'En revisión');

    expect(_consultas(api).last['estado'], 'EN_REVISION');
  });

  testWidgets('buscar envía el texto tras escribir', (tester) async {
    final api =
        await _montarUsuario(tester, {'incidencias': [], 'nextCursor': null});

    await tester.enterText(
      find.widgetWithText(
          TextField, 'Buscar incidencia, bicicletero o descripción'),
      'soporte',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(_consultas(api).last['q'], 'soporte');
  });

  testWidgets('registrar abre el formulario con los bicicleteros',
      (tester) async {
    await _montarUsuario(tester, {'incidencias': [], 'nextCursor': null});

    await tocarTexto(tester, 'Registrar');

    expect(find.text('Biblioteca Central'), findsWidgets);
  });

  testWidgets('central pasa una incidencia a revisión', (tester) async {
    final api = await _montarCentral(
      tester,
      extra: {
        'PATCH /incidencias/i1/estado': {
          'incidencia': _incidencia(estado: 'EN_REVISION'),
        },
      },
    );

    expect(find.text('Ana Rojas'), findsOneWidget);
    await tocarTexto(tester, 'En revisión');

    expect(
        api.cuerpoDe('PATCH /incidencias/i1/estado')['estado'], 'EN_REVISION');
    expect(find.text('Incidencia en revisión'), findsOneWidget);
  });

  testWidgets('central resuelve con una respuesta para el reportante',
      (tester) async {
    final api = await _montarCentral(
      tester,
      extra: {
        'PATCH /incidencias/i1/estado': {
          'incidencia': _incidencia(estado: 'RESUELTA'),
        },
      },
    );

    await tocarTexto(tester, 'Resolver');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Respuesta de cierre'),
      'Se reparó el soporte',
    );
    await tocarTexto(tester, 'Marcar resuelta');

    final cuerpo = api.cuerpoDe('PATCH /incidencias/i1/estado');
    expect(cuerpo['estado'], 'RESUELTA');
    expect(cuerpo['respuesta'], 'Se reparó el soporte');
    expect(find.text('Incidencia resuelta'), findsOneWidget);
  });

  testWidgets('cancelar el cierre no cambia la incidencia', (tester) async {
    final api = await _montarCentral(tester);

    await tocarTexto(tester, 'Descartar');
    await tocarTexto(tester, 'Cancelar');

    expect(api.llamadas, isNot(contains('PATCH /incidencias/i1/estado')));
  });
}
