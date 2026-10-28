import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/autenticacion/data/autenticacion_repositorio.dart';

class PerfilVm {
  const PerfilVm(this._ref);

  final Ref _ref;

  Future<String> solicitarCambioContrasena(String correo) => _ref
      .read(autenticacionRepositorioProvider)
      .solicitarCambioContrasena(correo);
}

final perfilVmProvider = Provider.autoDispose<PerfilVm>((ref) => PerfilVm(ref));
