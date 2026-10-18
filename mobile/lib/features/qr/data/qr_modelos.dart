import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

class QrTemporalApp {
  const QrTemporalApp({
    required this.id,
    required this.token,
    required this.tipo,
    required this.duracionSegundos,
    required this.expiraEn,
    required this.bicicleta,
    this.bicicletero,
  });

  final String id;
  final String token;
  final String tipo;
  final int duracionSegundos;
  final DateTime expiraEn;
  final BicicletaApp bicicleta;
  final BicicleteroApp? bicicletero;

  factory QrTemporalApp.desdeJson(Map<String, dynamic> json) {
    final bicicletaJson = json['bicicleta'] as Map<String, dynamic>;
    final bicicleteroJson = json['bicicletero'] as Map<String, dynamic>?;

    return QrTemporalApp(
      id: json['id'] as String,
      token: json['token'] as String,
      tipo: json['tipo'] as String,
      duracionSegundos: json['duracionSegundos'] as int,
      expiraEn: DateTime.parse(json['expiraEn'] as String),
      bicicleta: BicicletaApp(
        id: bicicletaJson['id'] as String,
        descripcion: bicicletaJson['descripcion'] as String,
        fotoUrl: null,
        activa: true,
        dentroBicicletero: json['tipo'] == 'RETIRO',
      ),
      bicicletero: bicicleteroJson == null
          ? null
          : BicicleteroApp.desdeJson(bicicleteroJson),
    );
  }
}

enum EstadoQr {
  escaneado,
  confirmado,
  denegado,
  liberado;

  bool get esFinal => this == EstadoQr.confirmado || this == EstadoQr.denegado;

  static EstadoQr? desdeApi(Object? valor) => switch (valor) {
        'ESCANEADO' => EstadoQr.escaneado,
        'CONFIRMADO' => EstadoQr.confirmado,
        'DENEGADO' => EstadoQr.denegado,
        'LIBERADO' || 'ACTIVO' || 'REEMPLAZADO' => EstadoQr.liberado,
        _ => null,
      };
}

class EventoQrApp {
  const EventoQrApp({
    required this.qrId,
    required this.estado,
    required this.tipo,
    this.motivo,
  });

  final String qrId;
  final EstadoQr estado;
  final String tipo;
  final String? motivo;

  bool get esIngreso => tipo == 'INGRESO';

  static EventoQrApp? desdeJson(Map<String, dynamic> json) {
    final qrId = json['qrId'];
    final estado = EstadoQr.desdeApi(json['estado']);
    final tipo = json['tipo'];
    if (qrId is! String || estado == null || tipo is! String) {
      return null;
    }

    final motivo = json['motivo'];
    return EventoQrApp(
      qrId: qrId,
      estado: estado,
      tipo: tipo,
      motivo: motivo is String && motivo.trim().isNotEmpty ? motivo : null,
    );
  }
}
