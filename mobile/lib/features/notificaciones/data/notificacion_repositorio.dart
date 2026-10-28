import 'package:ubbike/shared/modelos/notificacion_app.dart';
import 'package:ubbike/shared/modelos/pagina_cursor.dart';
import 'package:ubbike/features/notificaciones/data/notificacion_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/servicios/registro_dispositivo_push.dart';
import 'package:ubbike/core/providers/cliente_api_provider.dart';

class NotificacionRepositorio implements RegistroDispositivoPush {
  const NotificacionRepositorio(this._api);

  final NotificacionApi _api;

  Future<List<NotificacionApp>> listar() => _api.listar();
  Future<PaginaCursor<NotificacionApp>> listarPagina({String? cursor}) =>
      _api.listarPagina(cursor: cursor);

  Future<void> marcarTodasLeidas() => _api.marcarTodasLeidas();

  Future<void> marcarLeida(String notificacionId) =>
      _api.marcarLeida(notificacionId);

  @override
  Future<void> registrarDispositivo(String token) =>
      _api.registrarDispositivo(token);

  @override
  Future<void> eliminarDispositivo(String token) =>
      _api.eliminarDispositivo(token);
}

final notificacionRepositorioProvider =
    Provider<NotificacionRepositorio>((ref) {
  final cliente = ref.watch(clienteApiProvider);
  return NotificacionRepositorio(NotificacionApi(cliente: cliente));
});
