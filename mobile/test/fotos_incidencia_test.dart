import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/shared/modelos/incidencia_modelos.dart';
import 'package:ubbike/features/incidencias/presentation/galeria_fotos_incidencia.dart';
import 'package:ubbike/shared/widgets/selector_fotos_multiples.dart';

const _pngMinimo =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

Widget _envoltorio(Widget hijo) {
  return MaterialApp(
    theme: crearTemaUbb(),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: hijo,
      ),
    ),
  );
}

void main() {
  group('SelectorFotosMultiples', () {
    testWidgets('sin fotos invita a adjuntar y permite agregar',
        (tester) async {
      await tester.pumpWidget(
        _envoltorio(
          SelectorFotosMultiples(
            fotos: const [],
            maximo: 3,
            onCamara: () {},
            onGaleria: () {},
            onQuitar: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin fotos adjuntas'), findsOneWidget);
      expect(find.text('0 de 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('al llegar al maximo deshabilita los botones', (tester) async {
      await tester.pumpWidget(
        _envoltorio(
          SelectorFotosMultiples(
            fotos: const [_pngMinimo, _pngMinimo, _pngMinimo],
            maximo: 3,
            onCamara: () {},
            onGaleria: () {},
            onQuitar: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 de 3'), findsOneWidget);
      expect(find.text('Alcanzaste el máximo de 3 fotos.'), findsOneWidget);

      final camara = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Tomar foto'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(camara.onPressed, isNull);
    });

    testWidgets('quitar informa el indice correcto', (tester) async {
      final quitados = <int>[];

      await tester.pumpWidget(
        _envoltorio(
          SelectorFotosMultiples(
            fotos: const [_pngMinimo, _pngMinimo],
            maximo: 3,
            onCamara: () {},
            onGaleria: () {},
            onQuitar: quitados.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();

      expect(quitados, [1]);
    });

    testWidgets('tres fotos no desbordan en pantalla angosta', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _envoltorio(
          SelectorFotosMultiples(
            fotos: const [_pngMinimo, _pngMinimo, _pngMinimo],
            maximo: 3,
            ayuda: 'Adjunta evidencia del problema.',
            onCamara: () {},
            onGaleria: () {},
            onQuitar: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('GaleriaFotosIncidencia', () {
    testWidgets('sin fotos no ocupa espacio', (tester) async {
      await tester.pumpWidget(
        _envoltorio(const GaleriaFotosIncidencia(fotos: [])),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('anuncia la cantidad de evidencias', (tester) async {
      await tester.pumpWidget(
        _envoltorio(
          const GaleriaFotosIncidencia(
            fotos: [
              FotoIncidenciaApp(
                id: 'f1',
                url: '/uploads/incidencias/a.jpg',
                mimeType: 'image/jpeg',
                tamanoBytes: 1000,
              ),
              FotoIncidenciaApp(
                id: 'f2',
                url: '/uploads/incidencias/b.jpg',
                mimeType: 'image/jpeg',
                tamanoBytes: 1000,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('2 imágenes de evidencia'), findsOneWidget);
    });

    testWidgets('una sola evidencia usa el singular', (tester) async {
      await tester.pumpWidget(
        _envoltorio(
          const GaleriaFotosIncidencia(
            fotos: [
              FotoIncidenciaApp(
                id: 'f1',
                url: '/uploads/incidencias/a.jpg',
                mimeType: 'image/jpeg',
                tamanoBytes: 1000,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('1 imagen de evidencia'), findsOneWidget);
    });
  });

  group('modelo', () {
    test('parsea las fotos del backend', () {
      final incidencia = IncidenciaApp.desdeJson({
        'id': 'i1',
        'tipo': 'DANO_INFRAESTRUCTURA',
        'descripcion': 'Anclaje roto en el rack norte',
        'estado': 'PENDIENTE',
        'creadaEn': '2026-09-29T12:00:00.000Z',
        'actualizadaEn': '2026-09-29T12:00:00.000Z',
        'recordatorios': 0,
        'puedeRecordar': false,
        'bicicletero': {
          'id': 'b1',
          'nombre': 'Bicicletero FACE',
          'ubicacion': 'Campus',
        },
        'reportadaPorUsuario': {
          'id': 'u1',
          'nombre': 'Estudiante UBB',
          'correo': 'estudiante@alumnos.ubiobio.cl',
          'rol': 'ESTUDIANTE',
          'correoVerificado': true,
          'registroParcial': false,
          'cuentaActiva': true,
        },
        'fotos': [
          {
            'id': 'f1',
            'url': '/uploads/incidencias/a.jpg',
            'mimeType': 'image/jpeg',
            'tamanoBytes': 2048,
          },
        ],
      });

      expect(incidencia.fotos, hasLength(1));
      expect(incidencia.fotos.first.url, '/uploads/incidencias/a.jpg');
      expect(incidencia.fotos.first.tamanoBytes, 2048);
    });

    test('sin fotos devuelve lista vacia', () {
      final incidencia = IncidenciaApp.desdeJson({
        'id': 'i2',
        'tipo': 'OTRO',
        'descripcion': 'Sin evidencia adjunta',
        'estado': 'PENDIENTE',
        'creadaEn': '2026-09-29T12:00:00.000Z',
        'actualizadaEn': '2026-09-29T12:00:00.000Z',
        'recordatorios': 0,
        'puedeRecordar': false,
        'bicicletero': {
          'id': 'b1',
          'nombre': 'Bicicletero FACE',
          'ubicacion': 'Campus',
        },
        'reportadaPorUsuario': {
          'id': 'u1',
          'nombre': 'Estudiante UBB',
          'correo': 'estudiante@alumnos.ubiobio.cl',
          'rol': 'ESTUDIANTE',
          'correoVerificado': true,
          'registroParcial': false,
          'cuentaActiva': true,
        },
      });

      expect(incidencia.fotos, isEmpty);
    });
  });

  group('consumo de memoria', () {
    testWidgets('las miniaturas se decodifican al tamano que se muestran',
        (tester) async {
      await tester.pumpWidget(
        _envoltorio(
          SelectorFotosMultiples(
            fotos: const [_pngMinimo],
            maximo: 3,
            onCamara: () {},
            onGaleria: () {},
            onQuitar: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final imagen = tester.widget<Image>(find.byType(Image).first);
      expect(
        imagen.width,
        isNotNull,
        reason: 'la miniatura debe tener tamano fijo',
      );

      final proveedor = imagen.image;
      expect(
        proveedor,
        isA<ResizeImage>(),
        reason:
            'sin cacheWidth la foto se decodifica completa en memoria y Android '
            'mata la app al abrir la camara de nuevo',
      );
    });
  });
}
