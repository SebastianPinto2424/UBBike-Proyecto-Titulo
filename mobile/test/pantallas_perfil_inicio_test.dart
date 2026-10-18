import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/providers/conexion_provider.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/perfil/presentation/pantalla_principal_perfil.dart';
import 'package:ubbike/features/inicio/presentation/vista_dashboard_administrador.dart';
import 'package:ubbike/features/inicio/presentation/vista_dashboard_central.dart';
import 'package:ubbike/features/inicio/application/dashboard_administrador_vm.dart';
import 'package:ubbike/features/inicio/application/dashboard_central_vm.dart';
import 'package:ubbike/shared/modelos/historial_modelos.dart';
import 'package:ubbike/shared/modelos/incidencia_modelos.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/shared/modelos/dashboard_modelos.dart';
import 'package:ubbike/shared/widgets/atencion_operativa_widgets.dart';

final usuario = UsuarioApp.fromJson({
  'id': 'u',
  'nombre': 'Administrador UBBike',
  'correo': 'administrador@ubiobio.cl',
  'rut': '11.555.555-5',
  'rol': 'ADMINISTRADOR',
  'correoVerificado': true
});
final rack = BicicleteroApp.desdeJson({
  'id': 'rack',
  'nombre': 'Bicicletero FACE',
  'capacidad': 120,
  'ocupados': 22,
  'cuposDisponibles': 98,
  'porcentajeUso': 18
});
final central = DatosDashboardCentral(
  resumen: ResumenHistorialApp.desdeJson({
    'incidenciasAbiertas': 321,
    'usuariosActivos': 7,
    'usuariosInactivos': 0
  }),
  bicicleteros: [rack],
  solicitudes: [],
  movimientosRecientes: [],
  actualizadoEn: DateTime(2026, 9, 14, 15, 30),
  incidencias: [
    IncidenciaApp(
        id: 'i',
        tipo: 'OTRO',
        descripcion: 'La iluminación del acceso necesita revisión.',
        estado: 'PENDIENTE',
        creadaEn: DateTime.now().subtract(const Duration(minutes: 12)),
        actualizadaEn: DateTime.now(),
        bicicletero: rack,
        reportadaPorUsuario: usuario,
        recordatorios: 0,
        puedeRecordar: false)
  ],
);

class _Sesion extends SesionNotifier {
  @override
  Future<SesionState> build() async =>
      SesionActiva(usuario: usuario, token: 'test');
}

class _Dashboard extends DashboardAdministradorVm {
  @override
  Future<DatosDashboardAdministrador> build() async =>
      DatosDashboardAdministrador(central: central);
}

DatosDashboardCentral _sinIncidencias({int solicitudes = 0}) =>
    DatosDashboardCentral(
        resumen:
            ResumenHistorialApp.desdeJson({'solicitudesAbiertas': solicitudes}),
        bicicleteros: [rack],
        solicitudes: [],
        incidencias: [],
        movimientosRecientes: [],
        actualizadoEn: DateTime(2026, 9, 14, 19, 2));

class _AdministradorVacio extends DashboardAdministradorVm {
  @override
  Future<DatosDashboardAdministrador> build() async =>
      DatosDashboardAdministrador(central: _sinIncidencias());
}

class _CentralVacio extends DashboardCentralVm {
  @override
  Future<DatosDashboardCentral> build() async => _sinIncidencias();
}

Future<void> capturar(WidgetTester tester, GlobalKey key, String nombre) async {
  if (!const bool.fromEnvironment('CAPTURAR_UI')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final imagen = await boundary.toImage(pixelRatio: 2);
    final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
    final archivo = File('build/auditoria/$nombre.png');
    await archivo.parent.create(recursive: true);
    await archivo.writeAsBytes(bytes!.buffer.asUint8List());
    imagen.dispose();
  });
}

void main() {
  setUpAll(() async {
    const rutaFuente = String.fromEnvironment('UI_FONT_PATH');
    if (rutaFuente.isNotEmpty) {
      final loader = FontLoader('Roboto')
        ..addFont(
            File(rutaFuente).readAsBytes().then((b) => b.buffer.asByteData()));
      await loader.load();

      final plataforma = FontLoader('Ahem')
        ..addFont(
            File(rutaFuente).readAsBytes().then((b) => b.buffer.asByteData()));
      await plataforma.load();
      final iconos = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await iconos.load();
    }
  });
  for (final escala in [1.0, 1.8]) {
    for (final perfil in [true, false]) {
      testWidgets(
          '${perfil ? 'Perfil' : 'Inicio'} sin desbordes a escala $escala',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final onError = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          onError?.call(details);
        };
        await tester.pumpWidget(ProviderScope(
            overrides: [
              sesionProvider.overrideWith(_Sesion.new),
              dashboardAdministradorVmProvider.overrideWith(_Dashboard.new)
            ],
            child: MaterialApp(
              theme: crearTemaUbb(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(escala)),
                  child: child!),
              home: RepaintBoundary(
                  key: key,
                  child: Scaffold(
                      appBar: AppBar(title: Text(perfil ? 'Perfil' : 'Inicio')),
                      body: perfil
                          ? const VistaPerfil(rol: RolUsuario.administrador)
                          : VistaDashboardAdministrador(
                              onAbrirIncidencias: () {},
                              onAbrirUsuarios: () {}))),
            )));
        await tester.pumpAndSettle();
        FlutterError.onError = onError;
        expect(tester.takeException(), isNull);
        if (perfil) {
          expect(find.text('Datos de la cuenta'), findsOneWidget);
          expect(find.text('Seguridad'), findsOneWidget);
        } else {
          expect(find.text('321 abiertas'), findsOneWidget);
          expect(find.text('Requiere atención'), findsNothing);
        }
        if (escala == 1) {
          await capturar(tester, key, perfil ? 'perfil' : 'inicio');
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
      'no anuncia tiempo real cuando está desconectado o desactualizado',
      (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            home: Scaffold(body: PanelAtencionOperativa(datos: central)))));
    expect(find.textContaining('Sin conexión en vivo'), findsOneWidget);
    c.read(conexionProvider.notifier).state = EstadoConexion.conectado;
    await tester.pump();
    expect(find.textContaining('Conectado ·'), findsOneWidget);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            home: Scaffold(
                body: PanelAtencionOperativa(
                    datos: central.marcarDesactualizado())))));
    expect(find.textContaining('No pudimos actualizar'), findsOneWidget);
  });
  testWidgets(
      'tarjeta vacía compacta mantiene navegación y cambia al llegar incidencias',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(conexionProvider.notifier).state = EstadoConexion.conectado;
    var aperturas = 0;
    Widget pantalla(DatosDashboardCentral datos) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: crearTemaUbb(),
            home: Scaffold(
                body: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                        width: 350,
                        child: PanelAtencionOperativa(
                          datos: datos,
                          onAbrirIncidencias: () => aperturas++,
                        ))))));
    await tester.pumpWidget(pantalla(_sinIncidencias()));
    expect(find.text('Sin incidencias abiertas'), findsOneWidget);
    expect(find.text('0 abiertas'), findsNothing);
    expect(find.text('Ver abiertas'), findsNothing);
    expect(find.textContaining('Última consulta: 19:02'), findsOneWidget);
    final altoCompacto = tester
        .getSize(find.byKey(const Key('incidencias-sin-pendientes')))
        .height;
    await tester.tap(find.byTooltip('Ver incidencias abiertas'));
    await tester.pump();
    expect(aperturas, 1);
    await tester.pumpWidget(pantalla(central));
    expect(find.byKey(const Key('incidencias-sin-pendientes')), findsNothing);
    expect(find.text('321 abiertas'), findsOneWidget);
    expect(find.text('La iluminación del acceso necesita revisión.'),
        findsOneWidget);
    expect(tester.getSize(find.byType(Card).first).height,
        greaterThan(altoCompacto));
    await tester.pumpWidget(pantalla(_sinIncidencias()));
    expect(find.text('Sin incidencias abiertas'), findsOneWidget);
  });
  testWidgets(
      'tarjeta compacta no oculta desconexión, datos antiguos ni solicitudes',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var abierto = false;
    Widget pantalla(DatosDashboardCentral datos) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: crearTemaUbb(),
            home: Scaffold(
                body: PanelAtencionOperativa(
              datos: datos,
              onAbrirSolicitudes: () => abierto = true,
            ))));
    await tester.pumpWidget(pantalla(_sinIncidencias()));
    expect(find.textContaining('Sin conexión en vivo'), findsOneWidget);
    expect(find.textContaining('En vivo ·'), findsNothing);
    container.read(conexionProvider.notifier).state = EstadoConexion.conectado;
    await tester.pump();
    expect(find.textContaining('En vivo ·'), findsOneWidget);
    await tester.pumpWidget(
        pantalla(_sinIncidencias(solicitudes: 2).marcarDesactualizado()));
    expect(find.text('Último registro: sin incidencias'), findsOneWidget);
    expect(find.textContaining('No pudimos actualizar'), findsOneWidget);
    expect(find.textContaining('En vivo ·'), findsNothing);
    expect(find.text('Solicitudes de guardia'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('Solicitudes de guardia'));
    expect(abierto, isTrue);
  });
  for (final esCentral in [false, true]) {
    for (final escala in [1.0, 1.8]) {
      testWidgets(
          'inicio ${esCentral ? 'central' : 'administrador'} compacto sin desbordes a escala $escala',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(ProviderScope(
            overrides: [
              sesionProvider.overrideWith(_Sesion.new),
              dashboardAdministradorVmProvider
                  .overrideWith(_AdministradorVacio.new),
              dashboardCentralVmProvider.overrideWith(_CentralVacio.new),
              conexionProvider.overrideWith((ref) => EstadoConexion.conectado),
            ],
            child: MaterialApp(
              theme: crearTemaUbb(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(escala)),
                  child: child!),
              home: RepaintBoundary(
                  key: key,
                  child: Scaffold(
                      appBar: AppBar(title: const Text('Inicio')),
                      body: esCentral
                          ? VistaDashboardCentral(onAbrirIncidencias: () {})
                          : VistaDashboardAdministrador(
                              onAbrirIncidencias: () {}))),
            )));
        await tester.pumpAndSettle();
        expect(find.text('Sin incidencias abiertas'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (escala == 1) {
          await capturar(tester, key,
              esCentral ? 'inicio-central-compacto' : 'inicio-admin-compacto');
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
