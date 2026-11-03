import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:ubbike/core/configuracion/configuracion_mapa.dart';
import 'package:ubbike/core/providers/mapa_provider.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/admin/data/geocodificacion_repositorio.dart';
import 'package:ubbike/features/admin/presentation/hoja_formulario_bicicletero.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/modelos/lugar_encontrado.dart';
import 'package:ubbike/core/modelos/punto_geografico.dart';
import 'package:ubbike/core/servicios/ubicacion_servicio.dart';

late Uint8List _imagen;

class _TilesMemoria extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_imagen);
}

class _Gps extends UbicacionServicio {
  _Gps(this.posiciones);
  final Stream<Position> Function() posiciones;
  int llamadas = 0;
  @override
  Stream<Position> afinarPosicion({
    double precisionObjetivo = 10,
    Duration limite = const Duration(seconds: 15),
    Duration antiguedadMaxima = const Duration(minutes: 2),
  }) {
    llamadas++;
    return posiciones();
  }
}

class _Buscador implements GeocodificacionRepositorio {
  _Buscador(this.resultado);
  final Future<List<LugarEncontrado>> Function(String) resultado;
  final List<String> consultas = [];
  @override
  Future<List<LugarEncontrado>> buscar(String consulta) {
    consultas.add(consulta);
    return resultado(consulta);
  }
}

Position _posicion({double latitud = -36.821, double precision = 8}) =>
    Position(
        latitude: latitud,
        longitude: -73.011,
        timestamp: DateTime.now(),
        accuracy: precision,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0);

final _bicicletero = BicicleteroApp.desdeJson({
  'id': 'b',
  'nombre': 'FACE',
  'ubicacion': 'Acceso principal',
  'capacidad': 80,
  'latitud': -36.82,
  'longitud': -73.01
});

Future<void> _abrirHoja(
  WidgetTester tester, {
  BicicleteroApp? bicicletero,
  required Future<void> Function(DatosFormularioBicicletero) alGuardar,
  _Gps? gps,
  _Buscador? buscador,
  double escala = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ProviderScope(
      overrides: [
        fabricaTilesMapaProvider.overrideWithValue(() => _TilesMemoria()),
        ubicacionServicioProvider
            .overrideWithValue(gps ?? _Gps(() => const Stream.empty())),
        geocodificacionRepositorioProvider
            .overrideWithValue(buscador ?? _Buscador((_) async => const [])),
      ],
      child: MaterialApp(
        theme: crearTemaUbb(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escala)),
            child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showModalBottomSheet<bool>(
                          context: context,
                          showDragHandle: true,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => HojaFormularioBicicletero(
                              bicicletero: bicicletero, alGuardar: alGuardar),
                        ),
                    child: const Text('Abrir')))),
      )));
  await tester.tap(find.text('Abrir'));
  await _asentar(tester);
}

Future<void> _asentar(WidgetTester tester) async {
  await tester.pump();
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _datos(WidgetTester tester) async {
  await tester.enterText(
      find.byKey(const Key('bicicletero-nombre')), 'Bicicletero FACE');
  await tester.enterText(
      find.byKey(const Key('bicicletero-referencia')), 'Acceso principal');
  tester.testTextInput.hide();
  await tester.pump();
}

Future<void> _abrirUbicacion(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('agregar-ubicacion')));
  await tester.tap(find.byKey(const Key('agregar-ubicacion')));
  await _asentar(tester);
}

Future<void> _guardar(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('guardar-bicicletero')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('guardar-bicicletero')));
}

Future<void> _tocarMapa(WidgetTester tester, LatLng punto) async {
  tester.widget<FlutterMap>(find.byType(FlutterMap)).options.onTap!(
      const TapPosition(Offset.zero, Offset.zero), punto);
  await _asentar(tester);
}

void main() {
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 32, 32),
        Paint()..color = ColoresUbb.superficieAzul);
    final picture = recorder.endRecording();
    final image = await picture.toImage(32, 32);
    _imagen = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    image.dispose();
    picture.dispose();
  });

  group('hoja de bicicletero', () {
    testWidgets('guarda y se cierra cuando pasan las validaciones',
        (tester) async {
      DatosFormularioBicicletero? enviada;
      await _abrirHoja(tester, alGuardar: (datos) async {
        enviada = datos;
      });
      await _datos(tester);
      await _guardar(tester);
      await _asentar(tester);

      expect(enviada!.nombre, 'Bicicletero FACE');
      expect(enviada!.latitud, isNull);
      expect(find.byType(HojaFormularioBicicletero), findsNothing);
    });

    testWidgets('no llama al servidor si faltan datos obligatorios',
        (tester) async {
      var llamadas = 0;
      await _abrirHoja(tester, alGuardar: (_) async {
        llamadas++;
      });
      await _guardar(tester);
      await tester.pump();

      expect(find.text('Ingresa un nombre.'), findsOneWidget);
      expect(llamadas, 0);
      expect(find.byType(HojaFormularioBicicletero), findsOneWidget);
    });

    testWidgets('un error del servidor conserva los datos y deja reintentar',
        (tester) async {
      var intentos = 0;
      await _abrirHoja(tester, alGuardar: (_) async {
        intentos++;
        if (intentos == 1) throw Exception('sin red');
      });
      await _datos(tester);
      await _guardar(tester);
      await _asentar(tester);

      expect(find.textContaining('Tus datos siguen aquí'), findsOneWidget);
      expect(find.text('Bicicletero FACE'), findsOneWidget);

      await _guardar(tester);
      await _asentar(tester);
      expect(intentos, 2);
      expect(find.byType(HojaFormularioBicicletero), findsNothing);
    });

    testWidgets('bloquea el doble guardado mientras espera', (tester) async {
      final espera = Completer<void>();
      var intentos = 0;
      await _abrirHoja(tester, alGuardar: (_) {
        intentos++;
        return espera.future;
      });
      await _datos(tester);
      await _guardar(tester);
      await tester.pump();

      expect(
          tester
              .widget<ElevatedButton>(
                  find.byKey(const Key('guardar-bicicletero')))
              .onPressed,
          isNull);
      expect(intentos, 1);
      espera.complete();
      await _asentar(tester);
    });
  });

  group('panel de ubicación', () {
    testWidgets('arranca contraído y se despliega al agregar ubicación',
        (tester) async {
      await _abrirHoja(tester, alGuardar: (_) async {});

      expect(find.byKey(const Key('buscar-direccion')), findsNothing);
      expect(find.byType(FlutterMap), findsNothing);

      await _abrirUbicacion(tester);

      expect(find.byKey(const Key('buscar-direccion')), findsOneWidget);
      expect(find.byKey(const Key('usar-mi-ubicacion')), findsOneWidget);
      expect(find.byKey(const Key('alternar-coordenadas')), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('al editar con coordenadas ya viene desplegado',
        (tester) async {
      await _abrirHoja(tester,
          bicicletero: _bicicletero, alGuardar: (_) async {});

      expect(find.byKey(const Key('agregar-ubicacion')), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.textContaining('-36.820000, -73.010000'), findsWidgets);
    });

    testWidgets('el minimapa se contrae y se expande', (tester) async {
      await _abrirHoja(tester, alGuardar: (_) async {});
      await _abrirUbicacion(tester);
      expect(find.byType(FlutterMap), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('expandir-minimapa')));
      await tester.tap(find.byKey(const Key('expandir-minimapa')));
      await _asentar(tester);
      expect(find.byType(FlutterMap), findsNothing);

      await tester.tap(find.byKey(const Key('expandir-minimapa')));
      await _asentar(tester);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('buscar una dirección y elegirla fija el punto',
        (tester) async {
      final buscador = _Buscador((_) async => [
            const LugarEncontrado(
                titulo: 'Universidad del Bío-Bío',
                detalle: 'Collao, Concepción',
                punto: PuntoGeografico(-36.823142, -73.012512)),
          ]);
      DatosFormularioBicicletero? enviada;
      await _abrirHoja(tester, buscador: buscador, alGuardar: (datos) async {
        enviada = datos;
      });
      await _datos(tester);
      await _abrirUbicacion(tester);

      await tester.enterText(
          find.byKey(const Key('buscar-direccion')), 'Universidad');

      await tester.pump(const Duration(milliseconds: 700));
      await _asentar(tester);

      expect(buscador.consultas, ['Universidad']);
      expect(find.text('Universidad del Bío-Bío'), findsOneWidget);

      await tester.tap(find.text('Universidad del Bío-Bío'));
      await _asentar(tester);

      expect(find.textContaining('-36.823142, -73.012512'), findsWidgets);

      await _guardar(tester);
      await _asentar(tester);
      expect(enviada!.latitud, -36.823142);
      expect(enviada!.longitud, -73.012512);
    });

    testWidgets('no consulta el buscador con menos de tres caracteres',
        (tester) async {
      final buscador = _Buscador((_) async => const []);
      await _abrirHoja(tester, buscador: buscador, alGuardar: (_) async {});
      await _abrirUbicacion(tester);

      await tester.enterText(find.byKey(const Key('buscar-direccion')), 'Un');
      await tester.pump(const Duration(milliseconds: 700));
      await _asentar(tester);

      expect(buscador.consultas, isEmpty);
    });

    testWidgets('ingresar coordenadas a mano llega al guardado',
        (tester) async {
      DatosFormularioBicicletero? enviada;
      await _abrirHoja(tester, alGuardar: (datos) async {
        enviada = datos;
      });
      await _datos(tester);
      await _abrirUbicacion(tester);

      await tester.ensureVisible(find.byKey(const Key('alternar-coordenadas')));
      await tester.tap(find.byKey(const Key('alternar-coordenadas')));
      await _asentar(tester);

      await tester.enterText(
          find.byKey(const Key('bicicletero-latitud')), '-36.830000');
      await tester.enterText(
          find.byKey(const Key('bicicletero-longitud')), '-73.020000');
      tester.testTextInput.hide();
      await tester.pump();

      await _guardar(tester);
      await _asentar(tester);

      expect(enviada!.latitud, -36.83);
      expect(enviada!.longitud, -73.02);
    });

    testWidgets('rechaza coordenadas incompletas', (tester) async {
      var llamadas = 0;
      await _abrirHoja(tester, alGuardar: (_) async {
        llamadas++;
      });
      await _datos(tester);
      await _abrirUbicacion(tester);
      await tester.ensureVisible(find.byKey(const Key('alternar-coordenadas')));
      await tester.tap(find.byKey(const Key('alternar-coordenadas')));
      await _asentar(tester);

      await tester.enterText(
          find.byKey(const Key('bicicletero-latitud')), '-36.83');
      tester.testTextInput.hide();
      await tester.pump();
      await _guardar(tester);
      await tester.pump();

      expect(llamadas, 0);
      expect(find.textContaining('Indica latitud y longitud juntas'),
          findsWidgets);
    });

    testWidgets('marcar en el mapa fija el punto', (tester) async {
      DatosFormularioBicicletero? enviada;
      await _abrirHoja(tester, alGuardar: (datos) async {
        enviada = datos;
      });
      await _datos(tester);
      await _abrirUbicacion(tester);
      await _tocarMapa(tester, const LatLng(-36.823456, -73.012345));

      expect(find.textContaining('-36.823456, -73.012345'), findsWidgets);

      await _guardar(tester);
      await _asentar(tester);
      expect(enviada!.latitud, -36.823456);
      expect(enviada!.longitud, -73.012345);
    });

    testWidgets('quitar ubicación envía las dos coordenadas nulas',
        (tester) async {
      DatosFormularioBicicletero? enviada;
      await _abrirHoja(tester, bicicletero: _bicicletero,
          alGuardar: (datos) async {
        enviada = datos;
      });

      await tester.ensureVisible(find.byKey(const Key('quitar-ubicacion')));
      await tester.tap(find.byKey(const Key('quitar-ubicacion')));
      await _asentar(tester);

      await _guardar(tester);
      await _asentar(tester);

      expect(enviada!.latitud, isNull);
      expect(enviada!.longitud, isNull);
      expect(enviada!.nombre, 'FACE');
    });

    testWidgets('cambia entre capa estándar y satelital', (tester) async {
      await _abrirHoja(tester, alGuardar: (_) async {});
      await _abrirUbicacion(tester);

      expect(tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
          ConfiguracionMapa.urlDeCapa(CapaMapa.estandar));

      await tester.ensureVisible(find.text('Satélite'));
      await tester.tap(find.text('Satélite'));
      await _asentar(tester);

      expect(tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
          ConfiguracionMapa.urlDeCapa(CapaMapa.satelital));
      expect(find.text(ConfiguracionMapa.atribucionSatelital), findsOneWidget);
    });
  });

  group('GPS', () {
    testWidgets('no se pide solo al abrir la hoja', (tester) async {
      final gps = _Gps(() => Stream.value(_posicion()));
      await _abrirHoja(tester, gps: gps, alGuardar: (_) async {});
      await _abrirUbicacion(tester);

      expect(gps.llamadas, 0);
    });

    testWidgets(
        'usar mi ubicación fija el punto con la primera lectura y lo afina',
        (tester) async {
      final lecturas = StreamController<Position>.broadcast();
      final gps = _Gps(() => lecturas.stream);
      DatosFormularioBicicletero? enviada;
      await _abrirHoja(tester, gps: gps, alGuardar: (datos) async {
        enviada = datos;
      });
      await _datos(tester);
      await _abrirUbicacion(tester);

      await tester.ensureVisible(find.byKey(const Key('usar-mi-ubicacion')));
      await tester.tap(find.byKey(const Key('usar-mi-ubicacion')));
      await tester.pump();

      lecturas.add(_posicion(latitud: -36.825, precision: 35));
      await _asentar(tester);
      expect(gps.llamadas, 1);
      expect(find.textContaining('Precisión actual: 35 m'), findsOneWidget);
      expect(find.textContaining('-36.825000, -73.011000'), findsWidgets);

      lecturas.add(_posicion(precision: 8));
      await lecturas.close();
      await _asentar(tester);
      expect(find.textContaining('Precisión aproximada: 8 m'), findsOneWidget);
      expect(find.textContaining('-36.821000, -73.011000'), findsWidgets);

      await _guardar(tester);
      await _asentar(tester);
      expect(enviada!.latitud, -36.821);
    });

    testWidgets('sin resultado explica el problema', (tester) async {
      await _abrirHoja(tester,
          gps: _Gps(() => const Stream.empty()), alGuardar: (_) async {});
      await _abrirUbicacion(tester);

      await tester.ensureVisible(find.byKey(const Key('usar-mi-ubicacion')));
      await tester.tap(find.byKey(const Key('usar-mi-ubicacion')));
      await _asentar(tester);

      expect(find.textContaining('localización esté activada'), findsOneWidget);
    });

    testWidgets('marcar el punto a mano detiene el afinado del GPS',
        (tester) async {
      final lecturas = StreamController<Position>.broadcast();
      await _abrirHoja(tester,
          gps: _Gps(() => lecturas.stream), alGuardar: (_) async {});
      await _abrirUbicacion(tester);

      await tester.ensureVisible(find.byKey(const Key('usar-mi-ubicacion')));
      await tester.tap(find.byKey(const Key('usar-mi-ubicacion')));
      await tester.pump();

      await _tocarMapa(tester, const LatLng(-36.823456, -73.012345));
      lecturas.add(_posicion());
      await lecturas.close();
      await _asentar(tester);

      expect(lecturas.hasListener, isFalse);
      expect(find.textContaining('-36.823456, -73.012345'), findsWidgets);
      expect(find.textContaining('Precisión'), findsNothing);
      expect(find.text('Usar mi ubicación'), findsOneWidget);
    });
  });

  for (final escala in [1.0, 1.8]) {
    testWidgets('hoja sin desbordes con escala $escala', (tester) async {
      await _abrirHoja(tester,
          bicicletero: _bicicletero, alGuardar: (_) async {}, escala: escala);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('usar-mi-ubicacion')));
      expect(tester.takeException(), isNull);
    });
  }
}
