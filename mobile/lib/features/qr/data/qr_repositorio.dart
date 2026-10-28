import 'package:ubbike/features/qr/data/qr_api.dart';
import 'package:ubbike/features/qr/data/qr_modelos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/providers/cliente_api_provider.dart';

class QrRepositorio {
  const QrRepositorio(this._api);

  final QrApi _api;

  Future<EventoQrApp?> consultarEstado(String qrId) =>
      _api.consultarEstado(qrId);

  Future<QrTemporalApp> generar({
    String? bicicletaId,
    String? bicicleteroId,
    String? tipo,
  }) =>
      _api.generar(
        bicicletaId: bicicletaId,
        bicicleteroId: bicicleteroId,
        tipo: tipo,
      );
}

final qrRepositorioProvider = Provider<QrRepositorio>((ref) {
  final cliente = ref.watch(clienteApiProvider);
  return QrRepositorio(QrApi(cliente: cliente));
});
