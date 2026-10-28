import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/cliente_api_provider.dart';
import 'package:ubbike/shared/data/bicicleteros_api.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

class BicicleterosRepositorio {
  const BicicleterosRepositorio(this._api);

  final BicicleterosApi _api;

  Future<List<BicicleteroApp>> listar() => _api.listar();

  Future<void> asignarGuardia(String bicicleteroId, String guardiaId) =>
      _api.asignarGuardia(bicicleteroId, guardiaId);

  Future<String> liberarGuardia(String bicicleteroId) =>
      _api.liberarGuardia(bicicleteroId);
}

final bicicleterosRepositorioProvider =
    Provider<BicicleterosRepositorio>((ref) {
  final cliente = ref.watch(clienteApiProvider);
  return BicicleterosRepositorio(BicicleterosApi(cliente: cliente));
});
