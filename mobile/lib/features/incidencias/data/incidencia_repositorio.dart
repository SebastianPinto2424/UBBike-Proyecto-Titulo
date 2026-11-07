import 'package:ubbike/features/incidencias/data/incidencia_api.dart';
import 'package:ubbike/shared/modelos/incidencia_modelos.dart';
import 'package:ubbike/shared/modelos/pagina_cursor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/providers/cliente_api_provider.dart';

class IncidenciaRepositorio {
  const IncidenciaRepositorio(this._api);

  final IncidenciaApi _api;

  Future<PaginaCursor<IncidenciaApp>> listarPagina({
    String? estado,
    String? tipo,
    String? q,
    String? cursor,
    bool propias = false,
  }) =>
      _api.listarPagina(
        estado: estado,
        tipo: tipo,
        q: q,
        cursor: cursor,
        propias: propias,
      );

  Future<List<IncidenciaApp>> listar({
    String? estado,
    String? tipo,
    String? bicicleteroId,
    String? q,
    int? limite,
  }) =>
      _api.listar(
        estado: estado,
        tipo: tipo,
        bicicleteroId: bicicleteroId,
        q: q,
        limite: limite,
      );

  Future<IncidenciaApp> crear({
    required String bicicleteroId,
    required String tipo,
    required String descripcion,
    String? bicicletaId,
    List<String> fotos = const <String>[],
  }) =>
      _api.crear(
        bicicleteroId: bicicleteroId,
        tipo: tipo,
        descripcion: descripcion,
        bicicletaId: bicicletaId,
        fotos: fotos,
      );

  Future<IncidenciaApp> actualizarEstado({
    required String incidenciaId,
    required String estado,
    String? respuesta,
  }) =>
      _api.actualizarEstado(
        incidenciaId: incidenciaId,
        estado: estado,
        respuesta: respuesta,
      );

  Future<IncidenciaApp> recordar({required String incidenciaId}) =>
      _api.recordar(incidenciaId: incidenciaId);
}

final incidenciaRepositorioProvider = Provider<IncidenciaRepositorio>((ref) {
  final cliente = ref.watch(clienteApiProvider);
  return IncidenciaRepositorio(IncidenciaApi(cliente: cliente));
});
