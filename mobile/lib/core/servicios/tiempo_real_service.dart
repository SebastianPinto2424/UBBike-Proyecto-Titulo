import 'dart:async';
import 'package:ubbike/core/providers/conexion_provider.dart';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:ubbike/core/configuracion/configuracion_api.dart';

class TiempoRealService {
  TiempoRealService({this.alCambiarConexion});
  final void Function(EstadoConexion)? alCambiarConexion;
  io.Socket? _socket;
  String? _tokenActual;

  final _notificacionesController = StreamController<void>.broadcast();
  final _solicitudesController = StreamController<void>.broadcast();
  final _incidenciasController = StreamController<void>.broadcast();
  final _movimientosController = StreamController<void>.broadcast();
  final _usuariosController = StreamController<void>.broadcast();

  Stream<void> get notificaciones => _notificacionesController.stream;
  Stream<void> get solicitudes => _solicitudesController.stream;
  Stream<void> get incidencias => _incidenciasController.stream;
  Stream<void> get movimientos => _movimientosController.stream;
  Stream<void> get usuarios => _usuariosController.stream;

  void conectar(String token) {
    final tokenLimpio = token.trim();
    if (tokenLimpio.isEmpty) {
      desconectar();
      return;
    }

    if (_socket != null && _tokenActual == tokenLimpio) {
      if (_socket?.connected != true) {
        _socket?.connect();
      }
      return;
    }

    desconectar();
    _tokenActual = tokenLimpio;
    alCambiarConexion?.call(EstadoConexion.conectando);

    final socket = io.io(
      ConfiguracionApi.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .enableReconnection()
          .setReconnectionAttempts(8)
          .setReconnectionDelay(1000)
          .setTimeout(8000)
          .setAuth({'token': tokenLimpio})
          .build(),
    );

    socket.onConnect((_) {
      alCambiarConexion?.call(EstadoConexion.conectado);
      for (final controller in [
        _notificacionesController,
        _solicitudesController,
        _incidenciasController,
        _movimientosController,
        _usuariosController
      ]) {
        if (!controller.isClosed) controller.add(null);
      }
    });
    socket.onDisconnect(
        (_) => alCambiarConexion?.call(EstadoConexion.desconectado));
    socket.onConnectError(
        (_) => alCambiarConexion?.call(EstadoConexion.desconectado));
    socket.on('notificacion', (_) {
      if (!_notificacionesController.isClosed) {
        _notificacionesController.add(null);
      }
    });
    socket.on('solicitud', (_) {
      if (!_solicitudesController.isClosed) {
        _solicitudesController.add(null);
      }
    });
    socket.on('incidencia', (_) {
      if (!_incidenciasController.isClosed) {
        _incidenciasController.add(null);
      }
    });
    socket.on('movimiento', (_) {
      if (!_movimientosController.isClosed) {
        _movimientosController.add(null);
      }
    });
    socket.on('usuario', (_) {
      if (!_usuariosController.isClosed) {
        _usuariosController.add(null);
      }
    });

    _socket = socket;
    socket.connect();
  }

  void desconectar() {
    alCambiarConexion?.call(EstadoConexion.desconectado);
    final socket = _socket;
    if (socket != null) {
      socket.disconnect();
      socket.dispose();
    }
    _socket = null;
    _tokenActual = null;
  }

  void dispose() {
    desconectar();
    _notificacionesController.close();
    _solicitudesController.close();
    _incidenciasController.close();
    _movimientosController.close();
    _usuariosController.close();
  }
}
