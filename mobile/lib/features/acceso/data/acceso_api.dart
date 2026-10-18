import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';

class AccesoApi {
  const AccesoApi({required this.cliente});

  final ClienteApi cliente;

  Future<CoincidenciaManualApp?> buscarCoincidenciaManual({
    String? correo,
    String? rut,
  }) async {
    final parametros = <String, String>{
      if (correo != null && correo.isNotEmpty) 'correo': correo,
      if (rut != null && rut.isNotEmpty) 'rut': rut,
    };
    final consulta = Uri(queryParameters: parametros).query;
    final respuesta = await cliente.get('/accesos/manual/buscar?$consulta');
    final coincidencia = respuesta['coincidencia'] as Map<String, dynamic>?;

    return coincidencia == null
        ? null
        : CoincidenciaManualApp.desdeJson(coincidencia);
  }

  Future<QrValidadoApp> validarQr(String token) async {
    final respuesta = await cliente.post('/qr/validar', body: {'token': token});
    return QrValidadoApp.desdeJson(respuesta['qr'] as Map<String, dynamic>);
  }

  Future<void> liberarQr(String token) async {
    await cliente.post('/qr/liberar', body: {'token': token});
  }

  Future<MovimientoApp> confirmarQr(String token, {String? comentario}) async {
    final respuesta = await cliente.post(
      '/accesos/qr/confirmar',
      body: {
        'token': token,
        if (comentario != null && comentario.isNotEmpty)
          'comentario': comentario,
      },
    );
    return MovimientoApp.desdeJson(
      respuesta['movimiento'] as Map<String, dynamic>,
    );
  }

  Future<MovimientoApp> denegarQr({
    required String token,
    required String motivo,
  }) async {
    final respuesta = await cliente.post(
      '/accesos/qr/denegar',
      body: {
        'token': token,
        'motivo': motivo,
      },
    );
    return MovimientoApp.desdeJson(
      respuesta['movimiento'] as Map<String, dynamic>,
    );
  }

  Future<MovimientoApp> registrarManual(
    SolicitudRegistroManual solicitud,
  ) async {
    final respuesta = await cliente.post(
      '/accesos/manual',
      body: solicitud.aJson(),
    );
    return MovimientoApp.desdeJson(
      respuesta['movimiento'] as Map<String, dynamic>,
    );
  }
}
