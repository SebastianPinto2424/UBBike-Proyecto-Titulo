import 'dart:async';
import 'package:ubbike/core/providers/conexion_provider.dart';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:ubbike/core/configuracion/configuracion_api.dart';

bool esRechazoDelServidor(Object? error) =>
    error is Map && error['message'] != null;

bool esCierreDelServidor(Object? motivo) => motivo == 'io server disconnect';

String? motivoCierreSesion(Object? datos) {
  final motivo = datos is Map ? datos['motivo'] : null;
  return motivo is String ? motivo : null;
}

class TiempoRealServicio {
  TiempoRealServicio({this.alCambiarConexion});
  final void Function(EstadoConexion)? alCambiarConexion;
  io.Socket? _socket;
  String? _tokenActual;
  Timer? _vigilante;

  static const intervaloVigilancia = Duration(seconds: 15);

  final _controladorNotificaciones = StreamController<void>.broadcast();
  final _controladorSolicitudes = StreamController<void>.broadcast();
  final _controladorIncidencias = StreamController<void>.broadcast();
  final _controladorMovimientos = StreamController<void>.broadcast();
  final _controladorUsuarios = StreamController<void>.broadcast();
  final _controladorQr = StreamController<Map<String, dynamic>>.broadcast();
  final _controladorSesion = StreamController<String?>.broadcast();
  final _controladorBicicleteros = StreamController<void>.broadcast();
  final _controladorRechazos = StreamController<void>.broadcast();

  Stream<void> get notificaciones => _controladorNotificaciones.stream;
  Stream<void> get solicitudes => _controladorSolicitudes.stream;
  Stream<void> get incidencias => _controladorIncidencias.stream;
  Stream<void> get movimientos => _controladorMovimientos.stream;
  Stream<void> get usuarios => _controladorUsuarios.stream;
  Stream<String?> get sesionCerrada => _controladorSesion.stream;
  Stream<void> get bicicleteros => _controladorBicicleteros.stream;
  Stream<void> get rechazos => _controladorRechazos.stream;

  Stream<Map<String, dynamic>> get qr => _controladorQr.stream;

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
        _controladorNotificaciones,
        _controladorSolicitudes,
        _controladorIncidencias,
        _controladorMovimientos,
        _controladorUsuarios,
        _controladorBicicleteros,
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
      if (!_controladorNotificaciones.isClosed) {
        _controladorNotificaciones.add(null);
      }
    });
    socket.on('solicitud', (_) {
      if (!_controladorSolicitudes.isClosed) {
        _controladorSolicitudes.add(null);
      }
    });
    socket.on('incidencia', (_) {
      if (!_controladorIncidencias.isClosed) {
        _controladorIncidencias.add(null);
      }
    });
    socket.on('movimiento', (_) {
      if (!_controladorMovimientos.isClosed) {
        _controladorMovimientos.add(null);
      }
    });
    socket.on('usuario', (_) {
      if (!_controladorUsuarios.isClosed) {
        _controladorUsuarios.add(null);
      }
    });
    socket.on('bicicleteros', (_) {
      if (!_controladorBicicleteros.isClosed) {
        _controladorBicicleteros.add(null);
      }
    });
    socket.on('sesion', (datos) {
      if (!_controladorSesion.isClosed) {
        _controladorSesion.add(motivoCierreSesion(datos));
      }
    });
    socket.on('qr', (datos) {
      if (datos is Map && !_controladorQr.isClosed) {
        _controladorQr.add(Map<String, dynamic>.from(datos));
      }
    });

    _socket = socket;
    socket.connect();
    _vigilante = Timer.periodic(intervaloVigilancia, (_) {
      if (!socket.connected && !socket.active) socket.connect();
    });
  }

  void _avisarRechazo() {
    if (!_controladorRechazos.isClosed) _controladorRechazos.add(null);
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
    _controladorNotificaciones.close();
    _controladorSolicitudes.close();
    _controladorIncidencias.close();
    _controladorMovimientos.close();
    _controladorUsuarios.close();
    _controladorQr.close();
    _controladorSesion.close();
    _controladorBicicleteros.close();
    _controladorRechazos.close();
  }
}
