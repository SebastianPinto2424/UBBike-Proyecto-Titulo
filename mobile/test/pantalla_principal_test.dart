import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/app/principal/pantalla_principal.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/servicios/fcm_servicio.dart';

import 'soporte_api_falsa.dart';

Map<String, dynamic> _aviso(String id, String tipo) => {
      'id': id,
      'titulo': 'Aviso $tipo',
      'mensaje': 'Detalle del aviso',
      'tipo': tipo,
      'leida': false,
      'creadaEn': DateTime.now().toUtc().toIso8601String(),
    };

const _rutasBase = {
  'GET /bicicletas': {'bicicletas': []},
  'GET /bicicletas/activa': {'bicicleta': null},
  'GET /bicicleteros': {'bicicleteros': []},
  'GET /solicitudes-guardia': {'solicitudes': []},
  'GET /incidencias': {'incidencias': [], 'nextCursor': null},
  'GET /historial': {'movimientos': []},
  'GET /historial/opciones': {'bicicleteros': [], 'guardias': []},
  'GET /historial/resumen': {'resumen': {}},
  'GET /guardias/me/bicicletero': {'bicicletero': null},
  'GET /guardias': {'guardias': []},
  'GET /usuarios': {'usuarios': []},
};

Future<ApiFalsa> _montar(
  WidgetTester tester,
  RolUsuario rol, {
  List<Map<String, dynamic>> avisos = const [],
}) =>
    montarConApi(
      tester,
      const PantallaPrincipal(),
      conScaffold: false,
      rol: rol,
      rutas: {
        ..._rutasBase,
        'GET /notificaciones': {
          'notificaciones': avisos,
          'nextCursor': null,
          'noLeidas': avisos.length,
        },
        'PATCH /notificaciones/n1/leida': const {},
      },
    );

List<String> _destinos(WidgetTester tester) => tester
    .widgetList<NavigationDestination>(find.byType(NavigationDestination))
    .map((destino) => destino.label)
    .toList();

Future<void> _irA(WidgetTester tester, String destino) => tocar(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(destino),
      ),
    );

void main() {
  tearDown(() => FcmServicio.instancia.notificacionTocada.value = null);

  testWidgets('el estudiante navega entre sus secciones', (tester) async {
    await _montar(tester, RolUsuario.estudiante);

    expect(
        _destinos(tester), ['Inicio', 'Bicicletas', 'QR', 'Soporte', 'Perfil']);

    await _irA(tester, 'Bicicletas');
    expect(find.text('Sin bicicletas'), findsOneWidget);

    await _irA(tester, 'Soporte');
    expect(find.text('Atención del guardia'), findsOneWidget);
  });

  testWidgets('el guardia tiene validación y avisos', (tester) async {
    await _montar(tester, RolUsuario.guardia);

    expect(_destinos(tester),
        ['Inicio', 'Historial', 'Validar', 'Avisos', 'Perfil']);
    expect(find.text('Turno sin iniciar'), findsOneWidget);

    await _irA(tester, 'Avisos');
    expect(find.text('Sin alertas'), findsOneWidget);
  });

  testWidgets('central supervisa movimientos y guardias', (tester) async {
    await _montar(tester, RolUsuario.adminCentral);

    await _irA(tester, 'Guardias');
    expect(find.text('En turno'), findsOneWidget);
    expect(find.text('Sin bicicleteros activos'), findsOneWidget);

    await tocarTexto(tester, 'Operaciones');
    expect(find.text('Operaciones por guardia'), findsOneWidget);

    await _irA(tester, 'Movimientos');
    expect(find.text('Historial'), findsWidgets);
  });

  testWidgets('el administrador entra a la gestión', (tester) async {
    await _montar(tester, RolUsuario.administrador);

    await _irA(tester, 'Gestión');
    await tocarTexto(tester, 'Usuarios y permisos');

    expect(find.text('Sin usuarios'), findsOneWidget);
  });

  testWidgets('el administrador abre guardias desde el inicio', (tester) async {
    await _montar(tester, RolUsuario.administrador);

    await tocarTexto(tester, 'Gestionar');

    expect(find.text('En turno'), findsOneWidget);
    expect(find.text('Operaciones'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Guardias'), findsOneWidget);
  });

  testWidgets('muestra las no leídas y abre la bandeja', (tester) async {
    final api = await _montar(
      tester,
      RolUsuario.estudiante,
      avisos: [_aviso('n1', 'INCIDENCIA')],
    );

    expect(find.text('1'), findsOneWidget);

    await tocar(tester, find.byTooltip('Notificaciones'));
    expect(find.text('Aviso INCIDENCIA'), findsOneWidget);

    await tocarTexto(tester, 'Aviso INCIDENCIA');

    expect(api.llamadas, contains('PATCH /notificaciones/n1/leida'));
    expect(find.text('Sin incidencias'), findsOneWidget);
  });

  testWidgets('tocar un push de solicitud abre soporte', (tester) async {
    await _montar(tester, RolUsuario.guardia);

    FcmServicio.instancia.notificacionTocada.value = {
      'tipo': 'SOLICITUD_GUARDIA',
    };
    await tester.pumpAndSettle();

    expect(find.text('Sin alertas'), findsOneWidget);
    expect(FcmServicio.instancia.notificacionTocada.value, isNull);
  });

  testWidgets('tocar un push de movimiento abre el historial del usuario',
      (tester) async {
    await _montar(tester, RolUsuario.funcionario);

    FcmServicio.instancia.notificacionTocada.value = {'tipo': 'MOVIMIENTO'};
    await tester.pumpAndSettle();

    expect(find.text('Mis movimientos'), findsOneWidget);
  });
}
