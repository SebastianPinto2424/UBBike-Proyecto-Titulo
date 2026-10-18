import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/shared/modelos/incidencia_modelos.dart';
import 'package:ubbike/shared/modelos/pagina_cursor.dart';

class IncidenciaApi {
  const IncidenciaApi({required this.cliente});

  final ClienteApi cliente;

  Future<List<IncidenciaApp>> listar({
    String? estado,
    String? tipo,
    String? bicicleteroId,
    String? q,
    int? limite,
  }) async =>
      (await listarPagina(
              estado: estado,
              tipo: tipo,
              bicicleteroId: bicicleteroId,
              q: q,
              limite: limite))
          .datos;

  Future<PaginaCursor<IncidenciaApp>> listarPagina({
    String? cursor,
    String? estado,
    String? tipo,
    String? bicicleteroId,
    String? q,
    int? limite,
  }) async {
    final parametros = <String, String>{
      if (cursor != null) 'cursor': cursor,
      if (estado != null && estado != 'TODOS') 'estado': estado,
      if (tipo != null && tipo != 'TODOS') 'tipo': tipo,
      if (bicicleteroId != null && bicicleteroId.isNotEmpty)
        'bicicleteroId': bicicleteroId,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (limite != null && limite > 0) 'limite': limite.toString(),
    };
    final consulta =
        parametros.isEmpty ? '' : '?${Uri(queryParameters: parametros).query}';
    final respuesta = await cliente.get('/incidencias$consulta');
    final datos = respuesta['incidencias'] as List<dynamic>;

    return PaginaCursor(
      cursor: respuesta['nextCursor'] as String?,
      datos: datos
          .map((item) => IncidenciaApp.desdeJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<IncidenciaApp> crear({
    required String bicicleteroId,
    required String tipo,
    required String descripcion,
    String? bicicletaId,
    List<String> fotos = const <String>[],
  }) async {
    final respuesta = await cliente.post(
      '/incidencias',
      body: {
        'bicicleteroId': bicicleteroId,
        'tipo': tipo,
        'descripcion': descripcion,
        if (bicicletaId != null && bicicletaId.isNotEmpty)
          'bicicletaId': bicicletaId,
        if (fotos.isNotEmpty) 'fotos': fotos,
      },
    );

    return IncidenciaApp.desdeJson(
      respuesta['incidencia'] as Map<String, dynamic>,
    );
  }

  Future<IncidenciaApp> actualizarEstado({
    required String incidenciaId,
    required String estado,
    String? respuesta,
  }) async {
    final datos = await cliente.patch(
      '/incidencias/$incidenciaId/estado',
      body: {
        'estado': estado,
        if (respuesta != null && respuesta.trim().isNotEmpty)
          'respuesta': respuesta.trim(),
      },
    );

    return IncidenciaApp.desdeJson(
      datos['incidencia'] as Map<String, dynamic>,
    );
  }

  Future<IncidenciaApp> recordar({required String incidenciaId}) async {
    final datos = await cliente.post('/incidencias/$incidenciaId/recordar');

    return IncidenciaApp.desdeJson(
      datos['incidencia'] as Map<String, dynamic>,
    );
  }
}
