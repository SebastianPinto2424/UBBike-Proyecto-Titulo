import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/conexion_provider.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/core/servicios/tiempo_real_service.dart';

class PuenteTiempoReal {
  PuenteTiempoReal({
    required void Function(EstadoConexion estado) alCambiarConexion,
    required void Function(StateProvider<int> version) alCambiarVersion,
    required void Function(Map<String, dynamic> datos) alEventoQr,
    required void Function() alCerrarSesionRemota,
  }) : servicio = TiempoRealService(alCambiarConexion: alCambiarConexion) {
    _suscripciones = [
      servicio.solicitudes
          .listen((_) => alCambiarVersion(solicitudesGuardiaVersionProvider)),
      servicio.incidencias
          .listen((_) => alCambiarVersion(incidenciasVersionProvider)),
      servicio.movimientos
          .listen((_) => alCambiarVersion(movimientosVersionProvider)),
      servicio.usuarios
          .listen((_) => alCambiarVersion(usuariosVersionProvider)),
      servicio.bicicleteros
          .listen((_) => alCambiarVersion(bicicleterosVersionProvider)),
      servicio.qr.listen(alEventoQr),
      servicio.sesionCerrada.listen((_) => alCerrarSesionRemota()),
    ];
  }

  final TiempoRealService servicio;
  late final List<StreamSubscription<Object?>> _suscripciones;

  void dispose() {
    for (final suscripcion in _suscripciones) {
      suscripcion.cancel();
    }
    servicio.dispose();
  }
}
