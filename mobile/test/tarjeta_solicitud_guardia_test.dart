import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/acceso/presentation/solicitud_guardia_widgets.dart';
import 'package:ubbike/shared/modelos/solicitud_guardia_modelos.dart';

SolicitudGuardiaApp _solicitud({
  String estado = 'NOTIFICADA',
  bool conGuardia = true,
  String? enCaminoEn,
  String? resueltaEn,
  String? motivoCierre,
  String? cerradaPor,
  int notificacionesGuardia = 1,
}) =>
    SolicitudGuardiaApp.desdeJson({
      'id': 's1',
      'tipo': 'GUARDIA_AUSENTE',
      'estado': estado,
      'mensaje': 'No hay guardia en la caseta',
      'bicicletero': {'id': 'r1', 'nombre': 'Biblioteca Central'},
      'solicitante': {
        'id': 'u1',
        'nombre': 'Ana Rojas',
        'correo': 'ana@alumnos.ubiobio.cl',
        'rol': 'ESTUDIANTE',
      },
      'guardiaAsignado': conGuardia
          ? {'id': 'g1', 'nombre': 'Pedro Soto', 'rol': 'GUARDIA'}
          : null,
      'guardiasAsignados': const [],
      'creadaEn': '2026-10-20T13:30:00.000Z',
      'notificadaGuardiaEn': conGuardia ? '2026-10-20T13:30:00.000Z' : null,
      'notificacionesGuardia': notificacionesGuardia,
      'enCaminoEn': enCaminoEn,
      'resueltaEn': resueltaEn,
      'motivoCierre': motivoCierre,
      'cerradaPor': cerradaPor,
      'puedeNotificarGuardia': false,
      'segundosParaNotificarGuardia': 30,
    });

Future<List<String>> _montar(
  WidgetTester tester,
  SolicitudGuardiaApp solicitud, {
  bool mostrarSolicitante = false,
  bool mostrarAccionesGuardia = true,
  bool conCierreCentral = false,
  bool conAcciones = true,
  bool conCancelacion = false,
  Object? error,
}) async {
  final acciones = <String>[];
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: crearTemaUbb(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: TarjetaSolicitudGuardia(
            solicitud: solicitud,
            mostrarSolicitante: mostrarSolicitante,
            mostrarAccionesGuardia: mostrarAccionesGuardia,
            onActualizar: conAcciones
                ? (estado, {nota}) async {
                    acciones.add(nota == null ? estado : '$estado:$nota');
                    if (error != null) {
                      throw error;
                    }
                  }
                : null,
            onCerrarSinResolver:
                conCierreCentral ? () => acciones.add('CERRAR') : null,
            onCancelarSolicitante:
                conCancelacion ? () => acciones.add('CANCELAR') : null,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return acciones;
}

Future<void> _tocar(WidgetTester tester, String texto) async {
  await tester.ensureVisible(find.text(texto));
  await tester.tap(find.text(texto));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra el estado, el bicicletero y el mensaje', (tester) async {
    await _montar(tester, _solicitud(), mostrarSolicitante: true);

    expect(find.text('Guardia notificado'), findsWidgets);
    expect(find.textContaining('Biblioteca Central'), findsWidgets);
    expect(find.text('No hay guardia en la caseta'), findsOneWidget);
    expect(find.text('Ana Rojas'), findsOneWidget);
    expect(find.text('Pedro Soto'), findsOneWidget);
    expect(find.text('1 vez'), findsOneWidget);
  });

  testWidgets('el guardia confirma que va en camino', (tester) async {
    final acciones = await _montar(tester, _solicitud());

    await _tocar(tester, 'Voy en camino');

    expect(acciones, ['EN_CAMINO']);
    expect(find.text('Solicitud Guardia en camino'), findsOneWidget);
  });

  testWidgets('en camino ya no se puede volver a confirmar', (tester) async {
    final acciones = await _montar(
      tester,
      _solicitud(estado: 'EN_CAMINO', enCaminoEn: '2026-10-20T13:35:00.000Z'),
    );

    await tester.tap(find.text('Voy en camino'));
    await tester.pump();
    expect(acciones, isEmpty);

    await _tocar(tester, 'Marcar resuelta');
    expect(acciones, ['RESUELTA']);
  });

  testWidgets('si el backend rechaza el cambio muestra el motivo',
      (tester) async {
    await _montar(
      tester,
      _solicitud(),
      error: const ExcepcionApi('La solicitud ya está cerrada'),
    );

    await _tocar(tester, 'Marcar resuelta');

    expect(find.text('La solicitud ya está cerrada'), findsOneWidget);
  });

  testWidgets('central no marca resuelta, solo cierra sin resolver',
      (tester) async {
    final acciones = await _montar(
      tester,
      _solicitud(),
      mostrarAccionesGuardia: false,
      conCierreCentral: true,
    );

    expect(find.text('Marcar resuelta'), findsNothing);
    expect(find.text('Voy en camino'), findsNothing);

    await _tocar(tester, 'Cerrar sin resolver');

    expect(acciones, ['CERRAR']);
  });

  testWidgets('una solicitud cerrada por central muestra su motivo',
      (tester) async {
    await _montar(
      tester,
      _solicitud(
        estado: 'CANCELADA',
        resueltaEn: '2026-10-20T13:40:00.000Z',
        motivoCierre: 'Solicitud duplicada',
        cerradaPor: 'CENTRAL',
      ),
      conCierreCentral: true,
    );

    expect(find.text('Cerrada por central'), findsOneWidget);
    expect(find.text('Motivo de cierre (Central)'), findsOneWidget);
    expect(find.text('Solicitud duplicada'), findsOneWidget);
    expect(find.text('Voy en camino'), findsNothing);
    expect(find.text('Cerrar sin resolver'), findsNothing);
  });

  testWidgets('quien pidió atención puede cancelar una solicitud abierta',
      (tester) async {
    final acciones = await _montar(
      tester,
      _solicitud(),
      mostrarAccionesGuardia: false,
      conAcciones: false,
      conCancelacion: true,
    );

    final boton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Cancelar solicitud'),
        matching: find.byWidgetPredicate((widget) => widget is ElevatedButton),
      ),
    );
    expect(
      boton.style?.backgroundColor?.resolve(const <WidgetState>{}),
      ColoresUbb.rojoInstitucional,
    );
    expect(
      find.descendant(
        of: find.byWidget(boton),
        matching: find.byIcon(Icons.block),
      ),
      findsOneWidget,
    );

    await _tocar(tester, 'Cancelar solicitud');

    expect(acciones, ['CANCELAR']);
  });

  testWidgets('una solicitud cancelada por quien la pidió muestra su motivo',
      (tester) async {
    await _montar(
      tester,
      _solicitud(
        estado: 'CANCELADA',
        resueltaEn: '2026-10-20T13:40:00.000Z',
        motivoCierre: 'Ya lo resolví',
        cerradaPor: 'SOLICITANTE',
      ),
      mostrarAccionesGuardia: false,
      conAcciones: false,
      conCancelacion: true,
    );

    expect(find.text('Cancelada por el solicitante'), findsOneWidget);
    expect(find.text('Motivo del solicitante'), findsOneWidget);
    expect(find.text('Ya lo resolví'), findsOneWidget);
    expect(find.text('Cancelar solicitud'), findsNothing);
  });

  test('las etiquetas de estado son legibles', () {
    expect(etiquetaEstadoSolicitud('PENDIENTE'), 'Pendiente');
    expect(etiquetaEstadoSolicitud('EN_CAMINO'), 'Guardia en camino');
    expect(etiquetaEstadoSolicitud('OTRO'), 'OTRO');
  });
}
