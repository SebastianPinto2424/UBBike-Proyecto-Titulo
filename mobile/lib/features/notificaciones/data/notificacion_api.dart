import 'package:flutter/foundation.dart';
import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/shared/modelos/notificacion_app.dart';
import 'package:ubbike/shared/modelos/pagina_cursor.dart';

class NotificacionApi {
  const NotificacionApi({required this.cliente});

  final ClienteApi cliente;

  Future<List<NotificacionApp>> listar() async => (await listarPagina()).datos;

  Future<PaginaCursor<NotificacionApp>> listarPagina({String? cursor}) async {
    final consulta = cursor == null
        ? ''
        : '?${Uri(queryParameters: {'cursor': cursor}).query}';
    final respuesta = await cliente.get('/notificaciones$consulta');
    final datos = respuesta['notificaciones'] as List<dynamic>;
    return PaginaCursor(
      cursor: respuesta['nextCursor'] as String?,
      noLeidas: respuesta['noLeidas'] as int? ?? 0,
      datos: datos
          .map(
              (item) => NotificacionApp.desdeJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> marcarTodasLeidas() async {
    await cliente.patch('/notificaciones/leidas');
  }

  Future<void> marcarLeida(String notificacionId) async {
    await cliente.patch('/notificaciones/$notificacionId/leida');
  }

  Future<void> registrarDispositivo(String token, {String? plataforma}) async {
    await cliente.post(
      '/notificaciones/dispositivos',
      body: {
        'token': token,
        'plataforma': plataforma ?? plataformaPush(defaultTargetPlatform),
      },
    );
  }

  Future<void> eliminarDispositivo(String token) async {
    await cliente
        .delete('/notificaciones/dispositivos', body: {'token': token});
  }
}

String plataformaPush(TargetPlatform plataforma) =>
    plataforma == TargetPlatform.iOS ? 'ios' : 'android';
