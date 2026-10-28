import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/modelos/historial_modelos.dart';
import 'package:ubbike/shared/modelos/incidencia_modelos.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/modelos/solicitud_guardia_modelos.dart';

class DatosTableroCentral {
  const DatosTableroCentral({
    required this.resumen,
    required this.bicicleteros,
    required this.solicitudes,
    required this.incidencias,
    required this.movimientosRecientes,
    this.actualizadoEn,
    this.desactualizado = false,
  });

  final ResumenHistorialApp resumen;
  final List<BicicleteroApp> bicicleteros;
  final List<SolicitudGuardiaApp> solicitudes;
  final List<IncidenciaApp> incidencias;
  final List<MovimientoApp> movimientosRecientes;
  final DateTime? actualizadoEn;
  final bool desactualizado;
  int get totalIncidenciasAbiertas => resumen.incidenciasAbiertas;
  int get totalSolicitudesAbiertas => resumen.solicitudesAbiertas;

  DatosTableroCentral marcarDesactualizado() => DatosTableroCentral(
        resumen: resumen,
        bicicleteros: bicicleteros,
        solicitudes: solicitudes,
        incidencias: incidencias,
        movimientosRecientes: movimientosRecientes,
        actualizadoEn: actualizadoEn,
        desactualizado: true,
      );

  int get capacidadTotal =>
      bicicleteros.fold(0, (total, item) => total + item.capacidad);

  int get ocupadosTotal =>
      bicicleteros.fold(0, (total, item) => total + item.ocupados);

  int get cuposDisponiblesTotal =>
      bicicleteros.fold(0, (total, item) => total + item.cuposDisponibles);

  double get usoCampus => capacidadTotal == 0
      ? 0.0
      : (ocupadosTotal / capacidadTotal).clamp(0.0, 1.0).toDouble();

  List<SolicitudGuardiaApp> get solicitudesAbiertas => solicitudes
      .where((s) => s.estado != 'RESUELTA' && s.estado != 'CANCELADA')
      .toList();

  List<IncidenciaApp> get incidenciasAbiertas => incidencias
      .where((i) => i.estado != 'RESUELTA' && i.estado != 'DESCARTADA')
      .toList();

  List<BicicleteroApp> get bicicleterosCriticos {
    final lista = bicicleteros
        .where((b) => b.porcentajeUso >= 75 || b.cuposDisponibles <= 5)
        .toList()
      ..sort((a, b) => b.porcentajeUso.compareTo(a.porcentajeUso));
    return lista;
  }
}
