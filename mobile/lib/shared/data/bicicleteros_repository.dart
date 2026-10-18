import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/cliente_api_provider.dart';
import 'package:ubbike/shared/data/bicicleteros_api.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

class BicicleterosRepository {
  const BicicleterosRepository(this._api);

  final BicicleterosApi _api;

  Future<List<BicicleteroApp>> listar() => _api.listar();
}

final bicicleterosRepositoryProvider = Provider<BicicleterosRepository>((ref) {
  final cliente = ref.watch(clienteApiProvider);
  return BicicleterosRepository(BicicleterosApi(cliente: cliente));
});
