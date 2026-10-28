import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/notificaciones/data/notificacion_repositorio.dart';
import 'package:ubbike/shared/modelos/notificacion_app.dart';
import 'package:ubbike/shared/modelos/pagina_cursor.dart';

class NotificacionesVm {
  const NotificacionesVm(this._ref);

  final Ref _ref;

  Future<PaginaCursor<NotificacionApp>> listarPagina({String? cursor}) =>
      _ref.read(notificacionRepositorioProvider).listarPagina(cursor: cursor);

  Future<List<NotificacionApp>> listar() =>
      _ref.read(notificacionRepositorioProvider).listar();

  Future<void> marcarTodasLeidas() =>
      _ref.read(notificacionRepositorioProvider).marcarTodasLeidas();

  Future<void> marcarLeida(String notificacionId) =>
      _ref.read(notificacionRepositorioProvider).marcarLeida(notificacionId);
}

final notificacionesVmProvider = Provider.autoDispose<NotificacionesVm>(
  (ref) => NotificacionesVm(ref),
);
