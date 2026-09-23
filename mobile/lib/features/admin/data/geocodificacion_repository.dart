import 'package:ubbike/features/admin/data/geocodificacion_api.dart';
import 'package:ubbike/shared/modelos/lugar_encontrado.dart';

class GeocodificacionRepository {
  const GeocodificacionRepository(this._api);

  final GeocodificacionApi _api;

  Future<List<LugarEncontrado>> buscar(String consulta) =>
      _api.buscar(consulta);
}
