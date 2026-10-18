import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/qr/application/qr_usuario_vm.dart';
import 'package:ubbike/features/qr/data/qr_modelos.dart';
import 'package:ubbike/features/qr/presentation/vista_qr_usuario.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

const _bicicleta = BicicletaApp(
  id: 'bici-1',
  descripcion: 'Bici roja',
  activa: true,
  dentroBicicletero: true,
);

class _QrVmFalso extends QrUsuarioVm {
  _QrVmFalso(super.ref, this.alCambiarBicicleta, this.alGenerar, this.registro);

  final VoidCallback alCambiarBicicleta;
  final VoidCallback alGenerar;
  final _Registro registro;

  @override
  Future<EventoQrApp?> consultarEstado(String qrId) async =>
      registro.estadoServidor;

  @override
  Future<BicicletaApp?> obtenerActiva() async => _bicicleta;

  @override
  Future<List<BicicleteroApp>> listarBicicleteros() async => const [];

  @override
  Future<QrTemporalApp> generar({
    String? bicicletaId,
    String? bicicleteroId,
    String? tipo,
  }) async {
    alGenerar();
    return QrTemporalApp(
      id: 'qr-1',
      token: 'UBBIKE-prueba',
      tipo: 'RETIRO',
      duracionSegundos: 15,
      expiraEn: DateTime.now().subtract(const Duration(seconds: 1)),
      bicicleta: _bicicleta,
    );
  }

  @override
  void notificarCambioBicicleta() => alCambiarBicicleta();
}

class _Registro {
  int vecesHistorial = 0;
  int cambiosBicicleta = 0;
  int qrGenerados = 0;
  EventoQrApp? estadoServidor;
}

Future<ProviderContainer> _montarConQrGenerado(
  WidgetTester tester,
  _Registro registro,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        qrUsuarioVmProvider.overrideWith(
          (ref) => _QrVmFalso(
            ref,
            () => registro.cambiosBicicleta++,
            () => registro.qrGenerados++,
            registro,
          ),
        ),
      ],
      child: MaterialApp(
        theme: crearTemaUbb(),
        home: Scaffold(
          body: VistaQrUsuario(
            onVerHistorial: () => registro.vecesHistorial++,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Generar QR'));
  await tester.pump();
  await tester.pump();

  return ProviderScope.containerOf(tester.element(find.byType(VistaQrUsuario)));
}

void _emitir(ProviderContainer container, Map<String, dynamic> datos) {
  container.read(eventoQrProvider.notifier).recibir(datos);
}

void main() {
  group('EventoQrApp.desdeJson', () {
    test('interpreta el aviso de escaneo', () {
      final evento = EventoQrApp.desdeJson({
        'qrId': 'qr-1',
        'estado': 'ESCANEADO',
        'tipo': 'INGRESO',
      });

      expect(evento?.estado, EstadoQr.escaneado);
      expect(evento?.esIngreso, isTrue);
      expect(evento?.estado.esFinal, isFalse);
    });

    test('descarta avisos incompletos o con estado desconocido', () {
      expect(EventoQrApp.desdeJson({'estado': 'ESCANEADO'}), isNull);
      expect(
        EventoQrApp.desdeJson(
            {'qrId': 'qr-1', 'estado': 'OTRO', 'tipo': 'INGRESO'}),
        isNull,
      );
    });

    test('ignora un motivo vacío', () {
      final evento = EventoQrApp.desdeJson({
        'qrId': 'qr-1',
        'estado': 'DENEGADO',
        'tipo': 'RETIRO',
        'motivo': '   ',
      });

      expect(evento?.motivo, isNull);
      expect(evento?.estado.esFinal, isTrue);
    });
  });

  group('VistaQrUsuario en tiempo real', () {
    testWidgets(
        'al escanearse deja de mostrar el vencimiento y bloquea regenerar',
        (tester) async {
      final registro = _Registro();
      final container = await _montarConQrGenerado(tester, registro);
      expect(find.text('QR expirado'), findsOneWidget);

      _emitir(
          container, {'qrId': 'qr-1', 'estado': 'ESCANEADO', 'tipo': 'RETIRO'});
      await tester.pump();

      expect(find.text('Revisando tu retiro'), findsOneWidget);
      expect(find.text('QR expirado'), findsNothing);
      expect(find.text('Generar QR'), findsNothing);
      expect(find.text('Regenerar QR'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('al confirmarse lleva al historial tras la cuenta regresiva',
        (tester) async {
      final registro = _Registro();
      final container = await _montarConQrGenerado(tester, registro);

      _emitir(
          container, {'qrId': 'qr-1', 'estado': 'ESCANEADO', 'tipo': 'RETIRO'});
      await tester.pump();
      _emitir(container,
          {'qrId': 'qr-1', 'estado': 'CONFIRMADO', 'tipo': 'RETIRO'});
      await tester.pump();

      expect(find.text('Retiro confirmado'), findsOneWidget);
      expect(find.text('Te llevamos a tu historial en 4 s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(registro.vecesHistorial, 0);
      expect(find.text('Te llevamos a tu historial en 1 s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(registro.vecesHistorial, 1);
      expect(registro.cambiosBicicleta, 1);

      await tester.pump(const Duration(seconds: 5));
      expect(registro.vecesHistorial, 1);
    });

    testWidgets(
        'al denegarse muestra el motivo, se queda en pantalla y permite ir al '
        'historial', (tester) async {
      final registro = _Registro();
      final container = await _montarConQrGenerado(tester, registro);

      _emitir(container, {
        'qrId': 'qr-1',
        'estado': 'DENEGADO',
        'tipo': 'RETIRO',
        'motivo': 'La bicicleta no coincide',
      });
      await tester.pump();

      expect(find.text('Retiro denegado'), findsOneWidget);
      expect(find.text('Motivo: La bicicleta no coincide'), findsOneWidget);
      expect(find.textContaining('Te llevamos a tu historial'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      expect(registro.vecesHistorial, 0);

      await tester.tap(find.text('Ver historial'));
      await tester.pump();
      expect(registro.vecesHistorial, 1);
    });

    testWidgets('tras una denegación permite generar un nuevo QR',
        (tester) async {
      final registro = _Registro();
      final container = await _montarConQrGenerado(tester, registro);
      expect(registro.qrGenerados, 1);

      _emitir(container, {
        'qrId': 'qr-1',
        'estado': 'DENEGADO',
        'tipo': 'RETIRO',
        'motivo': 'La persona no es la titular',
      });
      await tester.pump();

      await tester.tap(find.text('Generar nuevo QR'));
      await tester.pump();
      await tester.pump();

      expect(registro.qrGenerados, 2);
      expect(find.text('Retiro denegado'), findsNothing);
      expect(
          find.text('Regenerar QR').evaluate().isNotEmpty ||
              find.text('Generar QR').evaluate().isNotEmpty,
          isTrue);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'si el guardia suelta el QR, vuelve a mostrarlo con la opción de '
        'generar otro', (tester) async {
      final registro = _Registro();
      final container = await _montarConQrGenerado(tester, registro);
      _emitir(
          container, {'qrId': 'qr-1', 'estado': 'ESCANEADO', 'tipo': 'RETIRO'});
      await tester.pump();
      expect(find.text('Revisando tu retiro'), findsOneWidget);

      _emitir(
          container, {'qrId': 'qr-1', 'estado': 'LIBERADO', 'tipo': 'RETIRO'});
      await tester.pump();

      expect(find.text('Revisando tu retiro'), findsNothing);
      expect(find.text('QR expirado'), findsOneWidget);
      expect(find.text('Generar QR'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('si la revisión tarda más de un minuto, ofrece generar otro QR',
        (tester) async {
      final registro = _Registro();
      final container = await _montarConQrGenerado(tester, registro);
      _emitir(
          container, {'qrId': 'qr-1', 'estado': 'ESCANEADO', 'tipo': 'RETIRO'});
      await tester.pump();
      expect(find.text('Generar nuevo QR'), findsNothing);

      await tester.pump(const Duration(minutes: 2));
      expect(find.text('Generar nuevo QR'), findsOneWidget);

      await tester.tap(find.text('Generar nuevo QR'));
      await tester.pump();
      await tester.pump();
      expect(registro.qrGenerados, 2);
      expect(find.text('Revisando tu retiro'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'si se pierde el aviso del guardia, consulta el estado y sale de la '
        'espera', (tester) async {
      final registro = _Registro();
      final container = await _montarConQrGenerado(tester, registro);
      _emitir(
          container, {'qrId': 'qr-1', 'estado': 'ESCANEADO', 'tipo': 'RETIRO'});
      await tester.pump();
      expect(find.text('Revisando tu retiro'), findsOneWidget);

      registro.estadoServidor = const EventoQrApp(
        qrId: 'qr-1',
        estado: EstadoQr.liberado,
        tipo: 'RETIRO',
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(find.text('Revisando tu retiro'), findsNothing);
      expect(find.text('Generar QR'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('si se pierde la confirmación, la recupera al consultar',
        (tester) async {
      final registro = _Registro();
      final container = await _montarConQrGenerado(tester, registro);
      _emitir(
          container, {'qrId': 'qr-1', 'estado': 'ESCANEADO', 'tipo': 'RETIRO'});
      await tester.pump();

      registro.estadoServidor = const EventoQrApp(
        qrId: 'qr-1',
        estado: EstadoQr.confirmado,
        tipo: 'RETIRO',
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(find.text('Retiro confirmado'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(registro.vecesHistorial, 1);
    });

    testWidgets('ignora avisos de otro QR', (tester) async {
      final registro = _Registro();
      final container = await _montarConQrGenerado(tester, registro);

      _emitir(container,
          {'qrId': 'qr-anterior', 'estado': 'CONFIRMADO', 'tipo': 'RETIRO'});
      await tester.pump();

      expect(find.text('Retiro confirmado'), findsNothing);
      expect(find.text('QR expirado'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(registro.vecesHistorial, 0);
    });
  });
}
