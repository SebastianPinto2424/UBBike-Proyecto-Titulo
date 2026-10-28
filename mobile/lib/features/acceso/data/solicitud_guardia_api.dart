import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/modelos/solicitud_guardia_modelos.dart';

class SolicitudGuardiaApi {
  const SolicitudGuardiaApi({required this.cliente});

  final ClienteApi cliente;

  Future<List<GuardiaTurnoApp>> listarGuardias() async {
    final respuesta = await cliente.get('/guardias');
    final datos = respuesta['guardias'] as List<dynamic>? ?? const [];
    return datos
        .whereType<Map<String, dynamic>>()
        .map(GuardiaTurnoApp.desdeJson)
        .toList();
  }

  Future<BicicleteroApp?> obtenerBicicleteroGestionado() async {
    final respuesta = await cliente.get('/guardias/me/bicicletero');
    final datos = respuesta['bicicletero'] as Map<String, dynamic>?;

    return datos == null ? null : BicicleteroApp.desdeJson(datos);
  }

  Future<BicicleteroApp> seleccionarBicicleteroGestionado(
    String bicicleteroId,
  ) async {
    final respuesta = await cliente.patch(
      '/guardias/me/bicicletero',
      body: {'bicicleteroId': bicicleteroId},
    );

    return BicicleteroApp.desdeJson(
      respuesta['bicicletero'] as Map<String, dynamic>,
    );
  }

  Future<void> liberarBicicleteroGestionado() async {
    await cliente.delete('/guardias/me/bicicletero');
  }

  Future<SolicitudGuardiaApp> crearSolicitud({
    required String bicicleteroId,
    required String tipo,
    String? mensaje,
  }) async {
    final respuesta = await cliente.post(
      '/solicitudes-guardia',
      body: {
        'bicicleteroId': bicicleteroId,
        'tipo': tipo,
        'mensaje': mensaje,
      },
    );

    return SolicitudGuardiaApp.desdeJson(
      respuesta['solicitud'] as Map<String, dynamic>,
    );
  }

  Future<SolicitudGuardiaApp> cancelarSolicitud({
    required String solicitudId,
    required String motivo,
  }) async {
    final respuesta = await cliente.post(
      '/solicitudes-guardia/$solicitudId/cancelar',
      body: {'motivo': motivo},
    );

    return SolicitudGuardiaApp.desdeJson(
      respuesta['solicitud'] as Map<String, dynamic>,
    );
  }

  Future<SolicitudGuardiaApp> notificarGuardia({
    required String solicitudId,
    String? mensaje,
  }) async {
    final respuesta = await cliente.post(
      '/solicitudes-guardia/$solicitudId/notificar-guardia',
      body: {
        if (mensaje != null && mensaje.isNotEmpty) 'mensaje': mensaje,
      },
    );

    return SolicitudGuardiaApp.desdeJson(
      respuesta['solicitud'] as Map<String, dynamic>,
    );
  }

  Future<List<SolicitudGuardiaApp>> listarSolicitudes({
    String? estado,
    String? q,
    int? limite,
  }) async {
    final parametros = <String, String>{
      if (estado != null && estado != 'TODOS') 'estado': estado,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (limite != null && limite > 0) 'limite': limite.toString(),
    };
    final consulta =
        parametros.isEmpty ? '' : '?${Uri(queryParameters: parametros).query}';
    final respuesta = await cliente.get('/solicitudes-guardia$consulta');
    final datos = respuesta['solicitudes'] as List<dynamic>;
    return datos
        .map((item) =>
            SolicitudGuardiaApp.desdeJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SolicitudGuardiaApp> actualizarEstado({
    required String solicitudId,
    required String estado,
    String? nota,
  }) async {
    final respuesta = await cliente.patch(
      '/solicitudes-guardia/$solicitudId/estado',
      body: {'estado': estado, if (nota != null) 'nota': nota},
    );

    return SolicitudGuardiaApp.desdeJson(
      respuesta['solicitud'] as Map<String, dynamic>,
    );
  }
}
