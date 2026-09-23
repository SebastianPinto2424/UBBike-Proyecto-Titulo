import 'package:ubbike/shared/modelos/notificacion_app.dart';
import 'package:ubbike/shared/modelos/pagina_cursor.dart';
import 'package:ubbike/features/notificaciones/data/notificacion_api.dart';

class NotificacionRepository {
  const NotificacionRepository(this._api);

  final NotificacionApi _api;

  Future<List<NotificacionApp>> listar() => _api.listar();
  Future<PaginaCursor<NotificacionApp>> listarPagina({String? cursor}) =>
      _api.listarPagina(cursor: cursor);

  Future<void> marcarTodasLeidas() => _api.marcarTodasLeidas();

  Future<void> marcarLeida(String notificacionId) =>
      _api.marcarLeida(notificacionId);

  Future<void> registrarDispositivo(String token) =>
      _api.registrarDispositivo(token);

  Future<void> eliminarDispositivo(String token) =>
      _api.eliminarDispositivo(token);
}
