import 'package:ubbike/features/admin/data/bicicleteros_admin_api.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/providers/cliente_api_provider.dart';

class BicicleterosAdminRepositorio {
  const BicicleterosAdminRepositorio(this._api);

  final BicicleterosAdminApi _api;

  Future<List<BicicleteroApp>> listar() => _api.listar();

  Future<BicicleteroApp> crear({
    required String nombre,
    required String ubicacion,
    required int capacidad,
    double? latitud,
    double? longitud,
  }) =>
      _api.crear(
        nombre: nombre,
        ubicacion: ubicacion,
        capacidad: capacidad,
        latitud: latitud,
        longitud: longitud,
      );

  Future<BicicleteroApp> actualizar({
    required String bicicleteroId,
    required String nombre,
    required String ubicacion,
    required int capacidad,
    double? latitud,
    double? longitud,
  }) =>
      _api.actualizar(
        bicicleteroId: bicicleteroId,
        nombre: nombre,
        ubicacion: ubicacion,
        capacidad: capacidad,
        latitud: latitud,
        longitud: longitud,
      );

  Future<void> eliminar(String bicicleteroId) => _api.eliminar(bicicleteroId);
}

final bicicleterosAdminRepositorioProvider =
    Provider<BicicleterosAdminRepositorio>((ref) {
  final cliente = ref.watch(clienteApiProvider);
  return BicicleterosAdminRepositorio(BicicleterosAdminApi(cliente: cliente));
});
