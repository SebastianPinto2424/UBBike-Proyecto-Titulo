import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/features/qr/data/qr_modelos.dart';

class QrApi {
  const QrApi({required this.cliente});

  final ClienteApi cliente;

  Future<QrTemporalApp> generar({
    String? bicicletaId,
    String? bicicleteroId,
    String? tipo,
  }) async {
    final respuesta = await cliente.post(
      '/qr/generar',
      body: {
        if (bicicletaId != null) 'bicicletaId': bicicletaId,
        if (bicicleteroId != null) 'bicicleteroId': bicicleteroId,
        if (tipo != null) 'tipo': tipo,
      },
    );

    return QrTemporalApp.desdeJson(respuesta['qr'] as Map<String, dynamic>);
  }

  Future<EventoQrApp?> consultarEstado(String qrId) async {
    final respuesta = await cliente.get('/qr/$qrId/estado');
    return EventoQrApp.desdeJson(respuesta['qr'] as Map<String, dynamic>);
  }
}
