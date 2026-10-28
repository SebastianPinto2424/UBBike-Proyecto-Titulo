import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/app/aplicacion_ubbike.dart';
import 'package:ubbike/app/principal/aviso_notificacion.dart';
import 'package:ubbike/app/principal/vista_menu_gestion.dart';
import 'package:ubbike/app/principal/vista_soporte.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/features/autenticacion/presentation/pantalla_inicio_sesion.dart';
import 'package:ubbike/shared/modelos/notificacion_app.dart';

import 'soporte_api_falsa.dart';

class _SesionFija extends SesionNotifier {
  _SesionFija(this.estado);

  final EstadoSesion estado;

  @override
  Future<EstadoSesion> build() async => estado;

  @override
  Future<void> cerrar() async => state = const AsyncData(SesionVacia());
}

Future<void> _abrirApp(
  WidgetTester tester, {
  EstadoSesion sesion = const SesionVacia(),
}) async {
  FlutterSecureStorage.setMockInitialValues({});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sesionProvider.overrideWith(() => _SesionFija(sesion))],
      child: const AplicacionUBBike(),
    ),
  );
  await tester.pumpAndSettle();
}

NotificacionApp _notificacion({Map<String, dynamic> datos = const {}}) =>
    NotificacionApp.desdeJson({
      'id': 'n1',
      'titulo': 'Guardia en camino',
      'mensaje': 'El guardia va en camino a Biblioteca.',
      'tipo': 'SOLICITUD_GUARDIA',
      'leida': false,
      'creadaEn': '2026-10-20T13:30:00.000Z',
      'datos': datos,
    });

void main() {
  group('arranque de la app', () {
    testWidgets('sin sesión abre el login sin avisos', (tester) async {
      await _abrirApp(tester);

      expect(find.byType(PantallaInicioSesion, skipOffstage: false),
          findsOneWidget);
      expect(find.textContaining('Cuenta activada'), findsNothing);
    });

    testWidgets('con contraseña temporal obliga a cambiarla', (tester) async {
      await _abrirApp(
        tester,
        sesion: const SesionActiva(
          token: 't',
          usuario: UsuarioApp(
            id: 'g1',
            nombre: 'Pedro Soto',
            correo: 'guardia@ubiobio.cl',
            rol: RolUsuario.guardia,
            correoVerificado: true,
            registroParcial: false,
            cuentaActiva: true,
            debeCambiarContrasena: true,
          ),
        ),
      );

      expect(find.text('Cambia tu contraseña'), findsOneWidget);
    });
  });

  group('aviso de notificación', () {
    testWidgets('muestra el aviso y permite verlo', (tester) async {
      var vista = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  avisoNotificacion(_notificacion(), onVer: () => vista++),
                ),
                child: const Text('avisar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('avisar'));
      await tester.pumpAndSettle();
      expect(find.text('Guardia en camino'), findsOneWidget);

      await tester.tap(find.text('Ver'));
      await tester.pumpAndSettle();
      expect(vista, 1);
    });

    testWidgets('el contador limita a 9+', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Row(children: [
          IconoNotificaciones(cantidad: 0),
          IconoNotificaciones(cantidad: 3),
          IconoNotificaciones(cantidad: 25),
        ]),
      ));

      expect(find.text('3'), findsOneWidget);
      expect(find.text('9+'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });

  group('soporte y gestión', () {
    const rutasSoporte = {
      'GET /solicitudes-guardia': {'solicitudes': []},
      'GET /incidencias': {'incidencias': [], 'nextCursor': null},
      'GET /bicicleteros': {'bicicleteros': []},
      'GET /historial': {'movimientos': []},
      'GET /historial/opciones': {'bicicleteros': [], 'guardias': []},
    };

    testWidgets('el usuario ve atención e incidencias', (tester) async {
      await montarConApi(tester, const VistaSoporteUsuario(),
          rutas: rutasSoporte);

      expect(find.text('Atención'), findsOneWidget);
      expect(find.text('Incidencias'), findsOneWidget);
      expect(find.text('Sin solicitudes recientes'), findsOneWidget);

      await tocarTexto(tester, 'Incidencias');
      expect(find.text('Sin incidencias'), findsOneWidget);
    });

    testWidgets('el guardia ve sus alertas', (tester) async {
      await montarConApi(tester, const VistaSoporteGuardia(),
          rol: RolUsuario.guardia, rutas: rutasSoporte);

      expect(find.text('Sin alertas'), findsOneWidget);
    });

    testWidgets('central ve las solicitudes', (tester) async {
      await montarConApi(tester, const VistaSoporteCentral(),
          rol: RolUsuario.adminCentral, rutas: rutasSoporte);

      expect(find.text('Sin solicitudes'), findsOneWidget);
    });

    testWidgets('el administrador atiende solicitudes e incidencias',
        (tester) async {
      await montarConApi(tester, const VistaSoporteAdministrador(),
          rol: RolUsuario.administrador, rutas: rutasSoporte);

      expect(find.text('Guardias'), findsNothing);
      expect(find.text('Incidencias'), findsOneWidget);
      expect(find.text('Sin solicitudes'), findsOneWidget);
    });

    testWidgets('el menú de gestión abre guardias', (tester) async {
      await montarConApi(
        tester,
        const VistaMenuGestionAdmin(),
        rol: RolUsuario.administrador,
        rutas: {
          ...rutasSoporte,
          'GET /guardias': {'guardias': []},
        },
      );

      await tocarTexto(tester, 'Guardias');

      expect(find.text('En turno'), findsOneWidget);
      expect(find.text('Operaciones'), findsOneWidget);
      expect(find.text('Sin bicicleteros activos'), findsOneWidget);
    });

    testWidgets('el menú de gestión abre usuarios y permisos', (tester) async {
      await montarConApi(
        tester,
        const VistaMenuGestionAdmin(),
        rol: RolUsuario.administrador,
        rutas: {
          ...rutasSoporte,
          'GET /usuarios': {'usuarios': []},
        },
      );

      await tocarTexto(tester, 'Usuarios y permisos');

      expect(find.text('Sin usuarios'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('el menú de gestión abre bicicleteros', (tester) async {
      await montarConApi(
        tester,
        const VistaMenuGestionAdmin(),
        rol: RolUsuario.administrador,
        rutas: rutasSoporte,
      );

      await tocarTexto(tester, 'Bicicleteros');

      expect(find.text('Sin bicicleteros'), findsOneWidget);
    });
  });
}
