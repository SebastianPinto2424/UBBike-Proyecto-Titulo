import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:ubbike/features/acceso/data/solicitud_guardia_repositorio.dart';
import 'package:ubbike/shared/data/bicicleteros_repositorio.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

class GuardiasEnTurnoVm {
  const GuardiasEnTurnoVm(this._ref);

  final Ref _ref;

  Future<List<BicicleteroApp>> listarBicicleteros() =>
      _ref.read(bicicleterosRepositorioProvider).listar();

  Future<List<GuardiaTurnoApp>> listarGuardias() =>
      _ref.read(solicitudGuardiaRepositorioProvider).listarGuardias();

  Future<String> liberar(String bicicleteroId) async {
    final mensaje = await _ref
        .read(bicicleterosRepositorioProvider)
        .liberarGuardia(bicicleteroId);
    _ref.read(bicicleterosVersionProvider.notifier).state++;
    return mensaje;
  }

  Future<void> asignar(String bicicleteroId, String guardiaId) async {
    await _ref
        .read(bicicleterosRepositorioProvider)
        .asignarGuardia(bicicleteroId, guardiaId);
    _ref.read(bicicleterosVersionProvider.notifier).state++;
  }
}

final guardiasEnTurnoVmProvider = Provider.autoDispose<GuardiasEnTurnoVm>(
  (ref) => GuardiasEnTurnoVm(ref),
);
