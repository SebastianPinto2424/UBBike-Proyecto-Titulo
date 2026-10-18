import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/bicicletas/data/bicicleta_repository.dart';
import 'package:ubbike/features/qr/data/qr_repository.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/features/qr/data/qr_modelos.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/data/bicicleteros_repository.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

class QrUsuarioVm {
  const QrUsuarioVm(this._ref);

  final Ref _ref;

  Future<QrTemporalApp> generar({
    String? bicicletaId,
    String? bicicleteroId,
    String? tipo,
  }) =>
      _ref.read(qrRepositoryProvider).generar(
            bicicletaId: bicicletaId,
            bicicleteroId: bicicleteroId,
            tipo: tipo,
          );

  Future<BicicletaApp?> obtenerActiva() =>
      _ref.read(bicicletaRepositoryProvider).obtenerActiva();

  Future<List<BicicleteroApp>> listarBicicleteros() =>
      _ref.read(bicicleterosRepositoryProvider).listar();

  Future<EventoQrApp?> consultarEstado(String qrId) =>
      _ref.read(qrRepositoryProvider).consultarEstado(qrId);

  void notificarCambioBicicleta() {
    _ref.read(bicicletasVersionProvider.notifier).state++;
  }
}

final qrUsuarioVmProvider = Provider.autoDispose<QrUsuarioVm>(
  (ref) => QrUsuarioVm(ref),
);

class EventoQrNotifier extends Notifier<EventoQrApp?> {
  @override
  EventoQrApp? build() => null;

  void recibir(Map<String, dynamic> datos) {
    final evento = EventoQrApp.desdeJson(datos);
    if (evento != null) {
      state = evento;
    }
  }
}

final eventoQrProvider = NotifierProvider<EventoQrNotifier, EventoQrApp?>(
  EventoQrNotifier.new,
);
