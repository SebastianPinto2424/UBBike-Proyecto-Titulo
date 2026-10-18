import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/servicios/registro_dispositivo_push.dart';
import 'package:ubbike/features/notificaciones/data/notificacion_repository.dart';
import 'package:ubbike/shared/modelos/notificacion_app.dart';
import 'package:ubbike/shared/utils/refresco_coalescido.dart';

class ControladorNotificaciones extends ChangeNotifier {
  ControladorNotificaciones({
    required NotificacionRepository notificacionRepository,
    Stream<void>? eventosTiempoReal,
    Duration intervalo = const Duration(seconds: 30),
  })  : _notificacionRepository = notificacionRepository,
        _eventosTiempoReal = eventosTiempoReal,
        _intervalo = intervalo;

  final NotificacionRepository _notificacionRepository;
  final Stream<void>? _eventosTiempoReal;
  final Duration _intervalo;
  final Set<String> _notificacionesConocidas = {};

  late final RefrescoCoalescido _refresco = RefrescoCoalescido(
    alRefrescar: () => actualizar(avisarNuevas: true),
    intervaloRespaldo: _intervalo,
  );
  StreamSubscription<void>? _suscripcionTiempoReal;
  bool _inicializado = false;
  bool _actualizando = false;
  bool _cerrado = false;
  int _noLeidas = 0;
  NotificacionApp? _nuevaNotificacion;

  int get noLeidas => _noLeidas;
  NotificacionApp? get nuevaNotificacion => _nuevaNotificacion;

  void iniciar() {
    actualizar();
    _suscripcionTiempoReal =
        _eventosTiempoReal?.listen((_) => _refresco.solicitar());
    _refresco.iniciarRespaldo();
  }

  Future<void> actualizar({bool avisarNuevas = false}) async {
    if (_actualizando) {
      return;
    }

    _actualizando = true;
    try {
      final pagina = await _notificacionRepository.listarPagina();
      if (_cerrado) return;
      final notificaciones = pagina.datos;
      final nuevas = notificaciones
          .where(
            (notificacion) =>
                !notificacion.leida &&
                !_notificacionesConocidas.contains(notificacion.id),
          )
          .toList();

      _notificacionesConocidas
        ..clear()
        ..addAll(notificaciones.map((notificacion) => notificacion.id));
      _noLeidas = pagina.noLeidas;
      _nuevaNotificacion = avisarNuevas && _inicializado && nuevas.isNotEmpty
          ? nuevas.first
          : null;
      _inicializado = true;
      notifyListeners();
    } catch (_) {
    } finally {
      _actualizando = false;
    }
  }

  void marcarNuevaNotificacionMostrada() {
    _nuevaNotificacion = null;
  }

  Future<void> marcarTodasLeidas() async {
    try {
      await _notificacionRepository.marcarTodasLeidas();
      if (_cerrado) return;
      await actualizar();
    } catch (_) {}
  }

  @override
  void dispose() {
    _cerrado = true;
    _refresco.detener();
    _suscripcionTiempoReal?.cancel();
    super.dispose();
  }
}

final crearControladorNotificacionesProvider =
    Provider<ControladorNotificaciones Function(Stream<void> eventos)>(
  (ref) => (eventos) => ControladorNotificaciones(
        notificacionRepository: ref.read(notificacionRepositoryProvider),
        eventosTiempoReal: eventos,
      ),
);

final registroDispositivoPushProvider = Provider<RegistroDispositivoPush>(
  (ref) => ref.watch(notificacionRepositoryProvider),
);
