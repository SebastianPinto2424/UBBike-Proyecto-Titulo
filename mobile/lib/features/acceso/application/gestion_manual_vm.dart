import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/features/acceso/data/acceso_repository.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/data/bicicleteros_repository.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';

class GestionManualVm {
  const GestionManualVm(this._ref);

  final Ref _ref;

  Future<CoincidenciaManualApp?> buscarCoincidencia({
    required String correo,
    required String rut,
  }) =>
      _ref.read(accesoRepositoryProvider).buscarCoincidenciaManual(
            correo: correo,
            rut: rut,
          );

  Future<MovimientoApp> registrarManual(SolicitudRegistroManual solicitud) =>
      _ref.read(accesoRepositoryProvider).registrarManual(solicitud);

  bool datoBusquedaSuficiente(String correo, String rut) {
    final rutLimpio = rut.replaceAll('.', '').replaceAll('-', '');
    return correo.contains('@') || rutLimpio.length >= 7;
  }

  BicicletaApp? bicicletaPreferidaAutodetectada(List<BicicletaApp> bicicletas) {
    if (bicicletas.isEmpty) {
      return null;
    }

    final dentroActivas = bicicletas.where(
      (bicicleta) => bicicleta.dentroBicicletero && bicicleta.activa,
    );
    if (dentroActivas.isNotEmpty) {
      return dentroActivas.first;
    }

    final dentro = bicicletas.where((bicicleta) => bicicleta.dentroBicicletero);
    if (dentro.isNotEmpty) {
      return dentro.first;
    }

    final activas = bicicletas.where((bicicleta) => bicicleta.activa);
    if (activas.isNotEmpty) {
      return activas.first;
    }

    return bicicletas.first;
  }

  String operacionParaBicicleta(BicicletaApp bicicleta) {
    return bicicleta.dentroBicicletero ? 'RETIRO' : 'INGRESO';
  }
}

final gestionManualVmProvider = Provider.autoDispose<GestionManualVm>(
  (ref) => GestionManualVm(ref),
);

final bicicleterosGestionManualProvider =
    FutureProvider.autoDispose<List<BicicleteroApp>>(
  (ref) {
    ref.watch(bicicleterosVersionProvider);
    return ref.watch(bicicleterosRepositoryProvider).listar();
  },
);
