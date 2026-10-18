import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/acceso/data/solicitud_guardia_repository.dart';
import 'package:ubbike/shared/modelos/solicitud_guardia_modelos.dart';
import 'package:ubbike/shared/data/bicicleteros_repository.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

class SolicitudesGuardiaVm {
  const SolicitudesGuardiaVm(this._ref);

  final Ref _ref;

  Future<List<BicicleteroApp>> listarBicicleteros() =>
      _ref.read(bicicleterosRepositoryProvider).listar();

  Future<BicicleteroApp?> obtenerBicicleteroGestionado() => _ref
      .read(solicitudGuardiaRepositoryProvider)
      .obtenerBicicleteroGestionado();

  Future<BicicleteroApp> seleccionarBicicleteroGestionado(
    String bicicleteroId,
  ) =>
      _ref
          .read(solicitudGuardiaRepositoryProvider)
          .seleccionarBicicleteroGestionado(bicicleteroId);

  Future<void> liberarBicicleteroGestionado() => _ref
      .read(solicitudGuardiaRepositoryProvider)
      .liberarBicicleteroGestionado();

  Future<void> crearSolicitud({
    required String bicicleteroId,
    required String tipo,
    String? mensaje,
  }) =>
      _ref.read(solicitudGuardiaRepositoryProvider).crearSolicitud(
            bicicleteroId: bicicleteroId,
            tipo: tipo,
            mensaje: mensaje,
          );

  Future<SolicitudGuardiaApp> notificarGuardia({
    required String solicitudId,
    String? mensaje,
  }) =>
      _ref.read(solicitudGuardiaRepositoryProvider).notificarGuardia(
            solicitudId: solicitudId,
            mensaje: mensaje,
          );

  Future<List<SolicitudGuardiaApp>> listarSolicitudes({
    String? estado,
    String? q,
    int? limite,
  }) =>
      _ref.read(solicitudGuardiaRepositoryProvider).listarSolicitudes(
            estado: estado,
            q: q,
            limite: limite,
          );

  Future<SolicitudGuardiaApp> actualizarEstado({
    required String solicitudId,
    required String estado,
    String? nota,
  }) =>
      _ref.read(solicitudGuardiaRepositoryProvider).actualizarEstado(
            solicitudId: solicitudId,
            estado: estado,
            nota: nota,
          );
}

final solicitudesGuardiaVmProvider = Provider.autoDispose<SolicitudesGuardiaVm>(
  (ref) => SolicitudesGuardiaVm(ref),
);
