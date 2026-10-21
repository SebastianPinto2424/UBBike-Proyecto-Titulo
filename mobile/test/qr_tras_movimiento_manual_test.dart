import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/qr/application/qr_usuario_vm.dart';
import 'package:ubbike/features/qr/data/qr_modelos.dart';
import 'package:ubbike/features/qr/presentation/seleccion_bicicletero_qr.dart';
import 'package:ubbike/features/qr/presentation/vista_qr_usuario.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

const _bicicletero = BicicleteroApp(
  id: 'bicicletero-1',
  nombre: 'Bicicletero FACE',
  ubicacion: 'Sector FACE',
  capacidad: 20,
  ocupados: 5,
  cuposDisponibles: 15,
  porcentajeUso: 25,
);

class _EstadoServidor {
  bool dentro = true;
  int consultasBicicleta = 0;
}

class _QrVmFalso extends QrUsuarioVm {
  _QrVmFalso(super.ref, this.servidor);

  final _EstadoServidor servidor;

  @override
  Future<BicicletaApp?> obtenerActiva() async {
    servidor.consultasBicicleta++;
    return BicicletaApp(
      id: 'bici-1',
      descripcion: 'Bici roja',
      activa: true,
      dentroBicicletero: servidor.dentro,
    );
  }

  @override
  Future<List<BicicleteroApp>> listarBicicleteros() async => const [
        _bicicletero,
      ];

  @override
  Future<EventoQrApp?> consultarEstado(String qrId) async => null;

  @override
  Future<QrTemporalApp> generar({
    String? bicicletaId,
    String? bicicleteroId,
    String? tipo,
  }) async {
    return QrTemporalApp(
      id: 'qr-1',
      token: 'UBBIKE-prueba',
      tipo: 'RETIRO',
      duracionSegundos: 15,
      expiraEn: DateTime.now().subtract(const Duration(seconds: 1)),
      bicicleta: const BicicletaApp(
        id: 'bici-1',
        descripcion: 'Bici roja',
        activa: true,
        dentroBicicletero: true,
      ),
    );
  }

  @override
  void notificarCambioBicicleta() {}
}

Future<ProviderContainer> _montar(
  WidgetTester tester,
  _EstadoServidor servidor,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        qrUsuarioVmProvider.overrideWith((ref) => _QrVmFalso(ref, servidor)),
      ],
      child: MaterialApp(
        theme: crearTemaUbb(),
        home: const Scaffold(body: VistaQrUsuario()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(VistaQrUsuario)));
}

void _avisarMovimiento(ProviderContainer container) {
  container.read(movimientosVersionProvider.notifier).state++;
}

void main() {
  testWidgets(
      'tras un retiro manual muestra el selector de bicicletero sin recargar',
      (tester) async {
    final servidor = _EstadoServidor();
    final container = await _montar(tester, servidor);
    expect(find.byType(SelectorBicicleteroQr), findsNothing);

    servidor.dentro = false;
    _avisarMovimiento(container);
    await tester.pumpAndSettle();

    expect(find.byType(SelectorBicicleteroQr), findsOneWidget);
  });

  testWidgets('no borra el resultado de un QR ya confirmado', (tester) async {
    final servidor = _EstadoServidor();
    final container = await _montar(tester, servidor);

    await tester.tap(find.text('Generar QR'));
    await tester.pump();
    await tester.pump();
    for (final estado in ['ESCANEADO', 'CONFIRMADO']) {
      container.read(eventoQrProvider.notifier).recibir({
        'qrId': 'qr-1',
        'estado': estado,
        'tipo': 'RETIRO',
      });
      await tester.pump();
    }
    final consultasAntes = servidor.consultasBicicleta;

    _avisarMovimiento(container);
    await tester.pump();

    expect(servidor.consultasBicicleta, consultasAntes);
    await tester.pump(const Duration(seconds: 5));
  });
}
