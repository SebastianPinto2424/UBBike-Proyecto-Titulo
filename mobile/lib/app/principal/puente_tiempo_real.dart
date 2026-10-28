import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/conexion_provider.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/core/servicios/tiempo_real_servicio.dart';

class PuenteTiempoReal {
  PuenteTiempoReal({
    required void Function(EstadoConexion estado) alCambiarConexion,
    required void Function(StateProvider<int> version) alCambiarVersion,
    required void Function(Map<String, dynamic> datos) alEventoQr,
    required void Function() alCerrarSesionRemota,
    required this.alRenovarSesion,
    TiempoRealServicio? servicio,
  }) : servicio = servicio ??
            TiempoRealServicio(alCambiarConexion: alCambiarConexion) {
    final origen = this.servicio;
    _suscripciones = [
      origen.solicitudes
          .listen((_) => alCambiarVersion(solicitudesGuardiaVersionProvider)),
      origen.incidencias
          .listen((_) => alCambiarVersion(incidenciasVersionProvider)),
      origen.movimientos
          .listen((_) => alCambiarVersion(movimientosVersionProvider)),
      origen.usuarios.listen((_) => alCambiarVersion(usuariosVersionProvider)),
      origen.bicicleteros
          .listen((_) => alCambiarVersion(bicicleterosVersionProvider)),
      origen.qr.listen(alEventoQr),
      origen.sesionCerrada.listen((_) => alCerrarSesionRemota()),
      origen.rechazos.listen((_) => _renovarSesion()),
    ];
  }

  static const esperaEntreRenovaciones = Duration(seconds: 15);

  final TiempoRealServicio servicio;
  final Future<void> Function() alRenovarSesion;
  late final List<StreamSubscription<Object?>> _suscripciones;
  DateTime? _ultimaRenovacion;

  void _renovarSesion() {
    final ahora = DateTime.now();
    final ultima = _ultimaRenovacion;
    if (ultima != null && ahora.difference(ultima) < esperaEntreRenovaciones) {
      return;
    }
    _ultimaRenovacion = ahora;
    unawaited(alRenovarSesion().catchError((Object _) {}));
  }

  void dispose() {
    for (final suscripcion in _suscripciones) {
      suscripcion.cancel();
    }
    servicio.dispose();
  }
}
