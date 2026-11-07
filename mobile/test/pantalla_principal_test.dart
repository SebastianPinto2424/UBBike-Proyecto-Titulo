import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/app/principal/pantalla_principal.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/servicios/fcm_servicio.dart';
import 'package:ubbike/features/qr/presentation/vista_qr_usuario.dart';

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

List<String?> _pestanas(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(TabBar), matching: find.byType(Text)),
    )
    .map((texto) => texto.data)
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
        ['Inicio', 'Historial', 'Validar', 'Avisos', 'Mi cuenta']);
    expect(find.text('Turno sin iniciar'), findsOneWidget);

    await _irA(tester, 'Avisos');
    expect(find.text('Sin alertas'), findsOneWidget);
  });

  for (final rol in [RolUsuario.estudiante, RolUsuario.funcionario]) {
    testWidgets('${rol.name} conserva el Perfil sin la sección personal',
        (tester) async {
      await _montar(tester, rol);

      await _irA(tester, 'Perfil');

      expect(find.text('Mi bicicleta'), findsNothing);
      expect(find.text('Mis bicicletas'), findsNothing);
      expect(find.text('Datos de la cuenta'), findsOneWidget);
    });
  }

  for (final rol in [
    RolUsuario.guardia,
    RolUsuario.adminCentral,
    RolUsuario.administrador,
  ]) {
    testWidgets('${rol.name} usa sus bicicletas, su QR y sus movimientos',
        (tester) async {
      final api = await _montar(tester, rol);

      await _irA(tester, 'Mi cuenta');
      expect(find.text('Mi bicicleta'), findsOneWidget);
      expect(_pestanas(tester), ['Mi bicicleta', 'Perfil']);
      expect(find.text('Atención e incidencias'), findsOneWidget);
      expect(find.text('Datos de la cuenta'), findsNothing);

      await tocar(
        tester,
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Perfil'),
        ),
      );
      expect(find.text('Datos de la cuenta'), findsOneWidget);
      expect(find.text('Mis bicicletas'), findsNothing);

      await tocar(
        tester,
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Mi bicicleta'),
        ),
      );
      await tocarTexto(tester, 'Mis bicicletas');

      expect(find.widgetWithText(AppBar, 'Mis bicicletas'), findsOneWidget);
      expect(find.text('Sin bicicletas'), findsOneWidget);
      expect(_pestanas(tester), ['Bicicletas', 'QR', 'Movimientos']);

      await tocar(
        tester,
        find.descendant(of: find.byType(TabBar), matching: find.text('QR')),
      );
      expect(find.byType(VistaQrUsuario), findsOneWidget);

      await tocar(
        tester,
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Movimientos'),
        ),
      );
      expect(find.text('Mis movimientos'), findsOneWidget);
      expect(
        api.peticiones
            .lastWhere((peticion) => peticion.url.path == '/historial')
            .url
            .queryParameters['alcance'],
        'PROPIO',
      );
    });

    testWidgets('${rol.name} pide atención y reporta incidencias propias',
        (tester) async {
      final api = await _montar(tester, rol);

      await _irA(tester, 'Mi cuenta');
      await tocarTexto(tester, 'Atención e incidencias');

      expect(find.widgetWithText(AppBar, 'Atención e incidencias'),
          findsOneWidget);
      expect(_pestanas(tester), ['Atención', 'Incidencias']);
      expect(
        api.peticiones
            .lastWhere(
              (peticion) => peticion.url.path == '/solicitudes-guardia',
            )
            .url
            .queryParameters['alcance'],
        'PROPIO',
      );

      await tocar(
        tester,
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Incidencias'),
        ),
      );
      expect(
        api.peticiones
            .lastWhere((peticion) => peticion.url.path == '/incidencias')
            .url
            .queryParameters['alcance'],
        'PROPIO',
      );
    });
  }

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

  testWidgets('el administrador valida al centro y atiende desde Soporte',
      (tester) async {
    final api = await _montar(tester, RolUsuario.administrador);

    expect(_destinos(tester),
        ['Inicio', 'Soporte', 'Validar', 'Gestión', 'Mi cuenta']);

    await _irA(tester, 'Validar');
    expect(_pestanas(tester), ['QR', 'Manual']);

    await _irA(tester, 'Soporte');
    expect(_pestanas(tester), ['Solicitudes', 'Incidencias']);
    expect(
      api.peticiones
          .where((peticion) => peticion.url.path == '/solicitudes-guardia')
          .every((peticion) =>
              !peticion.url.queryParameters.containsKey('alcance')),
      isTrue,
    );
  });

  testWidgets('un aviso sobre la solicitud propia abre la atención personal',
      (tester) async {
    await _montar(tester, RolUsuario.guardia);

    FcmServicio.instancia.notificacionTocada.value = {
      'tipo': 'SOLICITUD_GUARDIA',
      'alcance': 'PROPIO',
    };
    await tester.pumpAndSettle();

    expect(
        find.widgetWithText(AppBar, 'Atención e incidencias'), findsOneWidget);
    expect(find.text('Sin alertas'), findsNothing);
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

  testWidgets('un segundo aviso vuelve a abrir la pestaña que corresponde',
      (tester) async {
    await _montar(tester, RolUsuario.guardia);

    FcmServicio.instancia.notificacionTocada.value = {
      'tipo': 'SOLICITUD_GUARDIA',
    };
    await tester.pumpAndSettle();
    expect(find.text('Sin alertas'), findsOneWidget);

    await tocar(
      tester,
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Incidencias'),
      ),
    );
    expect(find.text('Sin alertas'), findsNothing);

    FcmServicio.instancia.notificacionTocada.value = {
      'tipo': 'SOLICITUD_GUARDIA',
    };
    await tester.pumpAndSettle();
    expect(find.text('Sin alertas'), findsOneWidget);
  });

  testWidgets('un aviso de incidencia abre la lista solo con las abiertas',
      (tester) async {
    final api = await _montar(tester, RolUsuario.guardia);

    FcmServicio.instancia.notificacionTocada.value = {'tipo': 'INCIDENCIA'};
    await tester.pumpAndSettle();

    final estados = api.peticiones
        .where((peticion) => peticion.url.path == '/incidencias')
        .map((peticion) => peticion.url.queryParameters['estado'])
        .toList();
    expect(estados, isNotEmpty);
    expect(estados, everyElement('ABIERTAS'));
  });

  testWidgets('el acceso rápido vuelve a abrir la gestión manual',
      (tester) async {
    await _montar(tester, RolUsuario.guardia);
    int pestanaActual() =>
        DefaultTabController.of(tester.element(find.byType(TabBar))).index;

    await tocarTexto(tester, 'Gestión manual');
    expect(pestanaActual(), 1);

    await tocar(
      tester,
      find.descendant(of: find.byType(TabBar), matching: find.text('QR')),
    );
    expect(pestanaActual(), 0);

    await _irA(tester, 'Inicio');
    await tocarTexto(tester, 'Gestión manual');
    expect(pestanaActual(), 1);
  });

  testWidgets('tocar un push de movimiento abre el historial del usuario',
      (tester) async {
    await _montar(tester, RolUsuario.funcionario);

    FcmServicio.instancia.notificacionTocada.value = {'tipo': 'MOVIMIENTO'};
    await tester.pumpAndSettle();

    expect(find.text('Mis movimientos'), findsOneWidget);
  });
}
