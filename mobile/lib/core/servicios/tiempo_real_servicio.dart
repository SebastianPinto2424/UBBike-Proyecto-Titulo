import 'dart:async';
import 'package:ubbike/core/providers/conexion_provider.dart';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:ubbike/core/configuracion/configuracion_api.dart';

bool esRechazoDelServidor(Object? error) =>
    error is Map && error['message'] != null;

bool esCierreDelServidor(Object? motivo) => motivo == 'io server disconnect';

class TiempoRealServicio {
  TiempoRealServicio({this.alCambiarConexion});
  final void Function(EstadoConexion)? alCambiarConexion;
  io.Socket? _socket;
  String? _tokenActual;
  Timer? _vigilante;

  static const intervaloVigilancia = Duration(seconds: 15);

  final _notificacionesController = StreamController<void>.broadcast();
  final _solicitudesController = StreamController<void>.broadcast();
  final _incidenciasController = StreamController<void>.broadcast();
  final _movimientosController = StreamController<void>.broadcast();
  final _usuariosController = StreamController<void>.broadcast();
  final _qrController = StreamController<Map<String, dynamic>>.broadcast();
  final _sesionController = StreamController<void>.broadcast();
  final _bicicleterosController = StreamController<void>.broadcast();
  final _rechazosController = StreamController<void>.broadcast();

  Stream<void> get notificaciones => _notificacionesController.stream;
  Stream<void> get solicitudes => _solicitudesController.stream;
  Stream<void> get incidencias => _incidenciasController.stream;
  Stream<void> get movimientos => _movimientosController.stream;
  Stream<void> get usuarios => _usuariosController.stream;
  Stream<void> get sesionCerrada => _sesionController.stream;
  Stream<void> get bicicleteros => _bicicleterosController.stream;
  Stream<void> get rechazos => _rechazosController.stream;

  Stream<Map<String, dynamic>> get qr => _qrController.stream;

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
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
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
        _usuariosController,
        _bicicleterosController,
      ]) {
        if (!controller.isClosed) controller.add(null);
      }
    });
    socket.onDisconnect((motivo) {
      alCambiarConexion?.call(EstadoConexion.desconectado);
      if (esCierreDelServidor(motivo)) _avisarRechazo();
    });
    socket.onConnectError((error) {
      alCambiarConexion?.call(EstadoConexion.desconectado);
      if (esRechazoDelServidor(error)) _avisarRechazo();
    });
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
    socket.on('bicicleteros', (_) {
      if (!_bicicleterosController.isClosed) {
        _bicicleterosController.add(null);
      }
    });
    socket.on('sesion', (_) {
      if (!_sesionController.isClosed) {
        _sesionController.add(null);
      }
    });
    socket.on('qr', (datos) {
      if (datos is Map && !_qrController.isClosed) {
        _qrController.add(Map<String, dynamic>.from(datos));
      }
    });

    _socket = socket;
    socket.connect();
    _vigilante = Timer.periodic(intervaloVigilancia, (_) {
      if (!socket.connected && !socket.active) socket.connect();
    });
  }

  void _avisarRechazo() {
    if (!_rechazosController.isClosed) _rechazosController.add(null);
  }

  void desconectar() {
    _vigilante?.cancel();
    _vigilante = null;
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
    _qrController.close();
    _sesionController.close();
    _bicicleterosController.close();
    _rechazosController.close();
  }
}
