import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/features/acceso/presentation/vista_escaner_qr_guardia.dart';

import 'soporte_api_falsa.dart';

const _camara = MethodChannel('dev.steenbakker.mobile_scanner/scanner/method');
const _lecturas = EventChannel('dev.steenbakker.mobile_scanner/scanner/event');

Map<String, dynamic> _qr({String tipo = 'INGRESO'}) => {
      'token': 'qr-123',
      'tipo': tipo,
      'expiraEn': DateTime.now()
          .add(const Duration(seconds: 15))
          .toUtc()
          .toIso8601String(),
      'usuario': {
        'nombre': 'Ana Rojas',
        'correo': 'ana@alumnos.ubiobio.cl',
        'rut': '11.111.111-1',
      },
      'bicicleta': {'descripcion': 'Urbana azul', 'marca': 'Oxford'},
      'bicicletero': {'nombre': 'Biblioteca Central'},
    };

Map<String, dynamic> _movimiento(String tipo, String estado) => {
      'movimiento': {
        'id': 'm1',
        'tipo': tipo,
        'estado': estado,
        'origen': 'QR',
        'creadoEn': DateTime.now().toUtc().toIso8601String(),
        'usuario': {'nombre': 'Ana Rojas', 'correo': 'ana@alumnos.ubiobio.cl'},
        'bicicleta': {'descripcion': 'Urbana azul'},
        'bicicletero': {'nombre': 'Biblioteca Central'},
        'guardia': {'nombre': 'Pedro Soto'},
      },
    };

void _simularCamara({bool permitida = true}) {
  final mensajero =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  mensajero.setMockMethodCallHandler(_camara, (llamada) async {
    switch (llamada.method) {
      case 'state':
        return permitida ? 1 : 2;
      case 'request':
        return permitida;
      case 'start':
        return {
          'textureId': 1,
          'numberOfCameras': 1,
          'currentTorchState': 0,
          'size': {'width': 640.0, 'height': 480.0},
        };
      default:
        return null;
    }
  });
  mensajero.setMockStreamHandler(
    _lecturas,
    MockStreamHandler.inline(onListen: (_, __) {}),
  );
  addTearDown(() {
    mensajero.setMockMethodCallHandler(_camara, null);
    mensajero.setMockStreamHandler(_lecturas, null);
  });
}

Future<ApiFalsa> _montar(
  WidgetTester tester, {
  Map<String, Object?> rutas = const {},
  bool camaraPermitida = true,
}) async {
  _simularCamara(permitida: camaraPermitida);
  return montarConApi(
    tester,
    const VistaEscanerQrGuardia(),
    rol: RolUsuario.guardia,
    rutas: {
      'POST /qr/validar': {'qr': _qr()},
      'POST /qr/liberar': const {},
      ...rutas,
    },
  );
}

Future<void> _leerQr(WidgetTester tester, String codigo) async {
  await tocarTexto(tester, 'Escanear QR');
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
    BarcodeCapture(barcodes: [Barcode(rawValue: codigo)]),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('antes de escanear indica cómo empezar', (tester) async {
    await _montar(tester);

    expect(find.text('QR no escaneado'), findsOneWidget);
    expect(find.text('Escanear QR'), findsOneWidget);
  });

  testWidgets('al leer un QR lo valida y muestra los datos', (tester) async {
    final api = await _montar(tester);

    await _leerQr(tester, 'qr-123');

    expect(api.cuerpoDe('POST /qr/validar'), {'token': 'qr-123'});
    expect(find.text('Ana Rojas'), findsWidgets);
    expect(find.text('Autorizar ingreso'), findsOneWidget);
  });

  testWidgets('un QR vencido muestra el motivo', (tester) async {
    await _montar(tester, rutas: {
      'POST /qr/validar': const RespuestaFalsa(
        400,
        {'message': 'El código QR expiró. Pide al usuario generar uno nuevo.'},
      ),
    });

    await _leerQr(tester, 'qr-viejo');

    expect(
      find.text('El código QR expiró. Pide al usuario generar uno nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Autorizar ingreso'), findsNothing);
  });

  testWidgets('un QR de la propia bicicleta muestra el aviso del servidor',
      (tester) async {
    const aviso =
        'No puedes registrar ni validar movimientos de tu propia bicicleta. Pídeselo a otro guardia.';
    await _montar(tester, rutas: {
      'POST /qr/validar': const RespuestaFalsa(403, {'message': aviso}),
    });

    await _leerQr(tester, 'qr-propio');

    expect(find.text(aviso), findsOneWidget);
    expect(find.text('Autorizar ingreso'), findsNothing);
  });

  testWidgets('confirmar el ingreso registra el movimiento', (tester) async {
    final api = await _montar(tester, rutas: {
      'POST /accesos/qr/confirmar': _movimiento('INGRESO', 'CONFIRMADO'),
    });

    await _leerQr(tester, 'qr-123');
    await tocarTexto(tester, 'Confirmar ingreso');

    expect(api.cuerpoDe('POST /accesos/qr/confirmar')['token'], 'qr-123');
    expect(find.text('Ingreso registrado'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('QR no escaneado'), findsOneWidget);
  });

  testWidgets('rechazar exige un motivo y lo envía', (tester) async {
    final api = await _montar(tester, rutas: {
      'POST /accesos/qr/denegar': _movimiento('INGRESO', 'DENEGADO'),
    });

    await _leerQr(tester, 'qr-123');
    await tocarTexto(tester, 'Rechazar ingreso');
    expect(find.text('Rechazar ingreso'), findsWidgets);

    await tocarTexto(tester, 'La bicicleta no coincide');
    await tocarTexto(tester, 'Rechazar');

    final cuerpo = api.cuerpoDe('POST /accesos/qr/denegar');
    expect(cuerpo['token'], 'qr-123');
    expect(cuerpo['motivo'], contains('La bicicleta no coincide'));
    expect(find.text('Ingreso rechazado'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('al abrir y cerrar el rechazo el cursor no vuelve al comentario',
      (tester) async {
    await _montar(tester);
    await _leerQr(tester, 'qr-123');
    final comentario =
        find.widgetWithText(TextFormField, 'Comentario opcional del guardia');
    await tester.ensureVisible(comentario);
    await tester.pumpAndSettle();
    await tester.enterText(comentario, 'Trae candado');
    expect(tester.testTextInput.hasAnyClients, isTrue);

    await tocarTexto(tester, 'Rechazar ingreso');
    expect(find.text('La bicicleta no coincide'), findsOneWidget);
    expect(tester.testTextInput.hasAnyClients, isFalse);

    await tocarTexto(tester, 'Cancelar');

    expect(find.text('La bicicleta no coincide'), findsNothing);
    expect(tester.testTextInput.hasAnyClients, isFalse);
    expect(find.text('Trae candado'), findsOneWidget);
  });

  testWidgets('leer otro libera el QR anterior', (tester) async {
    final api = await _montar(tester);

    await _leerQr(tester, 'qr-123');
    await tocarTexto(tester, 'Escanear nuevamente');

    expect(api.cuerpoDe('POST /qr/liberar'), {'token': 'qr-123'});
  });

  testWidgets('sin permiso de cámara lo explica', (tester) async {
    await _montar(tester, camaraPermitida: false);

    await tocarTexto(tester, 'Escanear QR');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Permite el uso de la cámara para escanear QR.'),
        findsWidgets);
  });
}
