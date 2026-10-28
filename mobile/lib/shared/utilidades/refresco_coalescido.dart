import 'dart:async';
import 'dart:math' as math;

class RefrescoCoalescido {
  RefrescoCoalescido({
    required Future<void> Function() alRefrescar,
    this.intervaloRespaldo = const Duration(seconds: 30),
    this.detectarFallo,
  }) : _alRefrescar = alRefrescar {
    _instancias.add(this);
  }

  final Future<void> Function() _alRefrescar;
  final Duration intervaloRespaldo;

  final bool Function()? detectarFallo;

  static final Set<RefrescoCoalescido> _instancias = {};

  static const _intervaloSinConexion = Duration(seconds: 10);
  static const _esperaMinimaTrasFallo = Duration(seconds: 2);

  static bool _aplicacionActiva = true;
  static bool _socketConectado = true;

  static bool get aplicacionActiva => _aplicacionActiva;

  static set aplicacionActiva(bool valor) {
    if (_aplicacionActiva == valor) {
      return;
    }

    _aplicacionActiva = valor;

    if (valor) {
      for (final instancia in _instancias.toList()) {
        instancia._reanudar();
      }
    }
  }

  static bool get socketConectado => _socketConectado;

  static set socketConectado(bool valor) {
    if (_socketConectado == valor) {
      return;
    }

    _socketConectado = valor;

    if (!valor) {
      for (final instancia in _instancias.toList()) {
        instancia._programarRespaldo();
      }
    }
  }

  Timer? _temporizador;
  bool _enVuelo = false;
  bool _pendiente = false;
  bool _detenido = false;
  bool _esperandoActivacion = false;
  int _fallosSeguidos = 0;

  bool get enVuelo => _enVuelo;

  void iniciarRespaldo() => _programarRespaldo();

  Future<void> solicitar() async {
    if (_detenido) {
      return;
    }

    if (_enVuelo) {
      _pendiente = true;
      return;
    }

    _enVuelo = true;
    _temporizador?.cancel();

    try {
      await _alRefrescar();
      _fallosSeguidos =
          (detectarFallo?.call() ?? false) ? _fallosSeguidos + 1 : 0;
    } catch (_) {
      _fallosSeguidos++;
    } finally {
      _enVuelo = false;

      if (!_detenido) {
        if (_pendiente) {
          _pendiente = false;
          unawaited(solicitar());
        } else {
          _programarRespaldo();
        }
      }
    }
  }

  Duration get _esperaSiguiente {
    if (_fallosSeguidos > 0) {
      final milisegundos = _esperaMinimaTrasFallo.inMilliseconds *
          math.pow(2, _fallosSeguidos - 1).toInt();
      return Duration(
        milliseconds: math.min(milisegundos, intervaloRespaldo.inMilliseconds),
      );
    }

    return _socketConectado ? intervaloRespaldo : _intervaloSinConexion;
  }

  void _programarRespaldo() {
    _temporizador?.cancel();

    if (_detenido) {
      return;
    }

    _temporizador = Timer(_esperaSiguiente, () {
      if (_aplicacionActiva) {
        unawaited(solicitar());
      } else {
        _esperandoActivacion = true;
      }
    });
  }

  void _reanudar() {
    if (_detenido) {
      return;
    }

    if (_esperandoActivacion) {
      _esperandoActivacion = false;
      unawaited(solicitar());
    } else {
      _programarRespaldo();
    }
  }

  void detener() {
    _detenido = true;
    _pendiente = false;
    _esperandoActivacion = false;
    _temporizador?.cancel();
    _temporizador = null;
    _instancias.remove(this);
  }
}
