import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/admin/data/geocodificacion_repository.dart';
import 'package:ubbike/shared/modelos/lugar_encontrado.dart';

class BuscadorLugaresVm {
  const BuscadorLugaresVm(this._ref);

  final Ref _ref;

  Future<List<LugarEncontrado>> buscar(String consulta) =>
      _ref.read(geocodificacionRepositoryProvider).buscar(consulta);
}

final buscadorLugaresVmProvider = Provider.autoDispose<BuscadorLugaresVm>(
  (ref) => BuscadorLugaresVm(ref),
);
