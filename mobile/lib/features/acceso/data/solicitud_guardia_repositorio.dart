import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:ubbike/features/acceso/data/solicitud_guardia_api.dart';
import 'package:ubbike/shared/modelos/solicitud_guardia_modelos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/providers/cliente_api_provider.dart';

class SolicitudGuardiaRepositorio {
  const SolicitudGuardiaRepositorio(this._api);

  final SolicitudGuardiaApi _api;

  Future<BicicleteroApp?> obtenerBicicleteroGestionado() =>
      _api.obtenerBicicleteroGestionado();

  Future<BicicleteroApp> seleccionarBicicleteroGestionado(
    String bicicleteroId,
  ) =>
      _api.seleccionarBicicleteroGestionado(bicicleteroId);

  Future<void> liberarBicicleteroGestionado() =>
      _api.liberarBicicleteroGestionado();

  Future<SolicitudGuardiaApp> crearSolicitud({
    required String bicicleteroId,
    required String tipo,
    String? mensaje,
  }) =>
      _api.crearSolicitud(
        bicicleteroId: bicicleteroId,
        tipo: tipo,
        mensaje: mensaje,
      );

  Future<List<GuardiaTurnoApp>> listarGuardias() => _api.listarGuardias();

  Future<SolicitudGuardiaApp> cancelarSolicitud({
    required String solicitudId,
    required String motivo,
  }) =>
      _api.cancelarSolicitud(solicitudId: solicitudId, motivo: motivo);

  Future<SolicitudGuardiaApp> notificarGuardia({
    required String solicitudId,
    String? mensaje,
  }) =>
      _api.notificarGuardia(solicitudId: solicitudId, mensaje: mensaje);

  Future<List<SolicitudGuardiaApp>> listarSolicitudes({
    String? estado,
    String? q,
    int? limite,
  }) =>
      _api.listarSolicitudes(estado: estado, q: q, limite: limite);

  Future<SolicitudGuardiaApp> actualizarEstado({
    required String solicitudId,
    required String estado,
    String? nota,
  }) =>
      _api.actualizarEstado(
          solicitudId: solicitudId, estado: estado, nota: nota);
}

final solicitudGuardiaRepositorioProvider =
    Provider<SolicitudGuardiaRepositorio>((ref) {
  final cliente = ref.watch(clienteApiProvider);
  return SolicitudGuardiaRepositorio(SolicitudGuardiaApi(cliente: cliente));
});
