import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/features/acceso/data/acceso_api.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/providers/cliente_api_provider.dart';

class AccesoRepositorio {
  const AccesoRepositorio(this._api);

  final AccesoApi _api;

  Future<CoincidenciaManualApp?> buscarCoincidenciaManual({
    String? correo,
    String? rut,
  }) =>
      _api.buscarCoincidenciaManual(correo: correo, rut: rut);

  Future<QrValidadoApp> validarQr(String token) => _api.validarQr(token);

  Future<void> liberarQr(String token) => _api.liberarQr(token);

  Future<MovimientoApp> confirmarQr(String token, {String? comentario}) =>
      _api.confirmarQr(token, comentario: comentario);

  Future<MovimientoApp> denegarQr({
    required String token,
    required String motivo,
  }) =>
      _api.denegarQr(token: token, motivo: motivo);

  Future<MovimientoApp> registrarManual(SolicitudRegistroManual solicitud) =>
      _api.registrarManual(solicitud);
}

final accesoRepositorioProvider = Provider<AccesoRepositorio>((ref) {
  final cliente = ref.watch(clienteApiProvider);
  return AccesoRepositorio(AccesoApi(cliente: cliente));
});
