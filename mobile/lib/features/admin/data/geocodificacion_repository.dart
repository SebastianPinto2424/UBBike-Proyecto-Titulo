import 'package:ubbike/features/admin/data/geocodificacion_api.dart';
import 'package:ubbike/shared/modelos/lugar_encontrado.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeocodificacionRepository {
  const GeocodificacionRepository(this._api);

  final GeocodificacionApi _api;

  Future<List<LugarEncontrado>> buscar(String consulta) =>
      _api.buscar(consulta);
}

final geocodificacionRepositoryProvider =
    Provider<GeocodificacionRepository>((ref) {
  return const GeocodificacionRepository(GeocodificacionApi());
});
