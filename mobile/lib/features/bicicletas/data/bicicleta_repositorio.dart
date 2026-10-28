import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/features/bicicletas/data/bicicleta_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/providers/cliente_api_provider.dart';

class BicicletaRepositorio {
  const BicicletaRepositorio(this._api);

  final BicicletaApi _api;

  Future<List<BicicletaApp>> listar() => _api.listar();

  Future<BicicletaApp?> obtenerActiva() => _api.obtenerActiva();

  Future<void> crear({
    required String descripcion,
    String? marca,
    String? modelo,
    String? color,
    String? aro,
    String? numeroSerie,
    String? fotoUrl,
    bool activar = false,
  }) =>
      _api.crear(
        descripcion: descripcion,
        marca: marca,
        modelo: modelo,
        color: color,
        aro: aro,
        numeroSerie: numeroSerie,
        fotoUrl: fotoUrl,
        activar: activar,
      );

  Future<void> actualizar({
    required String bicicletaId,
    required String descripcion,
    String? marca,
    String? modelo,
    String? color,
    String? aro,
    String? numeroSerie,
    String? fotoUrl,
    bool actualizarFoto = false,
  }) =>
      _api.actualizar(
        bicicletaId: bicicletaId,
        descripcion: descripcion,
        marca: marca,
        modelo: modelo,
        color: color,
        aro: aro,
        numeroSerie: numeroSerie,
        fotoUrl: fotoUrl,
        actualizarFoto: actualizarFoto,
      );

  Future<void> eliminar(String bicicletaId) => _api.eliminar(bicicletaId);

  Future<void> activar(String bicicletaId) => _api.activar(bicicletaId);

  Future<void> desactivar(String bicicletaId) => _api.desactivar(bicicletaId);
}

final bicicletaRepositorioProvider = Provider<BicicletaRepositorio>((ref) {
  final cliente = ref.watch(clienteApiProvider);
  return BicicletaRepositorio(BicicletaApi(cliente: cliente));
});
