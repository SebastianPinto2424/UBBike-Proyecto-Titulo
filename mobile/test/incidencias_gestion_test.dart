import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/incidencias/presentation/dialogo_respuesta_incidencia.dart';
import 'package:ubbike/features/incidencias/presentation/tarjeta_incidencia.dart';
import 'package:ubbike/shared/modelos/incidencia_modelos.dart';

IncidenciaApp _incidencia({
  String estado = 'PENDIENTE',
  String? respuesta,
  Map<String, dynamic>? gestionadaPor,
  Map<String, dynamic>? bicicleta,
  int recordatorios = 0,
  bool puedeRecordar = true,
  int? segundosParaRecordar = 0,
}) =>
    IncidenciaApp.desdeJson({
      'id': 'inc-1',
      'tipo': 'DANO_INFRAESTRUCTURA',
      'descripcion': 'El soporte del bicicletero está suelto',
      'estado': estado,
      'respuesta': respuesta,
      'creadaEn': '2026-10-20T13:30:00.000Z',
      'actualizadaEn': '2026-10-20T13:30:00.000Z',
      'recordatorios': recordatorios,
      'puedeRecordar': puedeRecordar,
      'segundosParaRecordar': segundosParaRecordar,
      'bicicletero': {'id': 'r1', 'nombre': 'Biblioteca Central'},
      'bicicleta': bicicleta,
      'reportadaPorUsuario': {
        'id': 'u1',
        'nombre': 'Ana Rojas',
        'correo': 'ana@alumnos.ubiobio.cl',
        'rol': 'ESTUDIANTE',
      },
      'gestionadaPorUsuario': gestionadaPor,
      'fotos': const [],
    });

Future<void> _montarTarjeta(
  WidgetTester tester,
  IncidenciaApp incidencia, {
  bool mostrarReportante = false,
  bool puedeGestionar = false,
  bool gestionGuardia = false,
  bool mostrarRecordar = false,
  ValueChanged<String>? onActualizarEstado,
  VoidCallback? onRecordar,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: crearTemaUbb(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: TarjetaIncidencia(
            incidencia: incidencia,
            mostrarReportante: mostrarReportante,
            puedeGestionar: puedeGestionar,
            gestionGuardia: gestionGuardia,
            mostrarRecordar: mostrarRecordar,
            onActualizarEstado: onActualizarEstado ?? (_) {},
            onRecordar: onRecordar ?? () {},
            onEsperaCumplida: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('tarjeta de incidencia', () {
    testWidgets('muestra tipo, estado y datos principales', (tester) async {
      await _montarTarjeta(
        tester,
        _incidencia(
          bicicleta: {'id': 'b1', 'descripcion': 'Urbana azul'},
          gestionadaPor: {
            'id': 'a1',
            'nombre': 'Central UBB',
            'rol': 'ADMIN_CENTRAL'
          },
          respuesta: 'Se coordinó la reparación',
          estado: 'EN_REVISION',
        ),
        mostrarReportante: true,
      );

      expect(find.text('Daño de infraestructura'), findsOneWidget);
      expect(find.text('En revisión'), findsOneWidget);
      expect(
          find.text('El soporte del bicicletero está suelto'), findsOneWidget);
      expect(find.text('Biblioteca Central'), findsOneWidget);
      expect(find.text('Urbana azul'), findsOneWidget);
      expect(find.text('Ana Rojas'), findsOneWidget);
      expect(find.text('Central UBB'), findsOneWidget);
      expect(find.text('Se coordinó la reparación'), findsOneWidget);
    });

    testWidgets('oculta al reportante cuando no corresponde', (tester) async {
      await _montarTarjeta(tester, _incidencia());

      expect(find.text('Reportada por'), findsNothing);
      expect(find.text('Ana Rojas'), findsNothing);
      expect(find.text('Resolver'), findsNothing);
    });

    testWidgets('central puede revisar, resolver o descartar', (tester) async {
      final estados = <String>[];
      await _montarTarjeta(
        tester,
        _incidencia(),
        puedeGestionar: true,
        onActualizarEstado: estados.add,
      );

      await tester.tap(find.text('En revisión'));
      await tester.tap(find.text('Resolver'));
      await tester.tap(find.text('Descartar'));

      expect(estados, ['EN_REVISION', 'RESUELTA', 'DESCARTADA']);
    });

    testWidgets('en revisión no se puede volver a marcar en revisión',
        (tester) async {
      final estados = <String>[];
      await _montarTarjeta(
        tester,
        _incidencia(estado: 'EN_REVISION'),
        puedeGestionar: true,
        onActualizarEstado: estados.add,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'En revisión'));

      expect(estados, isEmpty);
    });

    testWidgets('el guardia gestiona pero no puede descartar', (tester) async {
      await _montarTarjeta(
        tester,
        _incidencia(),
        puedeGestionar: true,
        gestionGuardia: true,
      );

      expect(find.text('Resolver'), findsOneWidget);
      expect(find.text('Descartar'), findsNothing);
    });

    testWidgets('una incidencia cerrada no ofrece acciones', (tester) async {
      await _montarTarjeta(
        tester,
        _incidencia(estado: 'RESUELTA'),
        puedeGestionar: true,
        mostrarRecordar: true,
      );

      expect(find.text('Resuelta'), findsOneWidget);
      expect(find.text('Resolver'), findsNothing);
      expect(find.text('Recordar'), findsNothing);
    });

    testWidgets('quien reportó puede recordar cuando terminó la espera',
        (tester) async {
      var recordada = 0;
      await _montarTarjeta(
        tester,
        _incidencia(recordatorios: 1),
        mostrarRecordar: true,
        onRecordar: () => recordada++,
      );

      await tester.tap(find.text('Recordar de nuevo'));

      expect(recordada, 1);
    });
  });

  group('diálogo de cierre de incidencia', () {
    Future<List<String?>> abrir(WidgetTester tester, String estado) async {
      final resultados = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: crearTemaUbb(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    resultados.add(
                      await showDialog<String>(
                        context: context,
                        builder: (_) => DialogoRespuestaGestion(
                          incidencia: _incidencia(),
                          estado: estado,
                          respuestaInicial: '',
                        ),
                      ),
                    );
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return resultados;
    }

    testWidgets('exige explicar el cierre', (tester) async {
      final resultados = await abrir(tester, 'RESUELTA');

      expect(find.text('Marcar incidencia como resuelta'), findsOneWidget);
      expect(
        find.text(
          'Esta respuesta le llegará a Ana Rojas por correo y notificación.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Marcar resuelta'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa una respuesta de cierre.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Listo');
      await tester.tap(find.text('Marcar resuelta'));
      await tester.pumpAndSettle();
      expect(
        find.text('Debe explicar el cierre con al menos 8 caracteres.'),
        findsOneWidget,
      );
      expect(resultados, isEmpty);
    });

    testWidgets('devuelve la respuesta sin espacios sobrantes', (tester) async {
      final resultados = await abrir(tester, 'RESUELTA');

      await tester.enterText(
        find.byType(TextFormField),
        '  Se reparó el soporte  ',
      );
      await tester.tap(find.text('Marcar resuelta'));
      await tester.pumpAndSettle();

      expect(resultados, ['Se reparó el soporte']);
    });

    testWidgets('descartar usa la acción destructiva y se puede cancelar',
        (tester) async {
      final resultados = await abrir(tester, 'DESCARTADA');

      expect(find.text('Descartar incidencia'), findsOneWidget);
      expect(find.text('Descartar'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(resultados, [null]);
    });
  });
}
