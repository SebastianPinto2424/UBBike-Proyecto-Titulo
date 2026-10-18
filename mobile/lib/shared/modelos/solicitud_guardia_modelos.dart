import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';

class SolicitudGuardiaApp {
  const SolicitudGuardiaApp({
    required this.id,
    required this.tipo,
    required this.estado,
    required this.bicicletero,
    required this.solicitante,
    required this.creadaEn,
    required this.puedeNotificarGuardia,
    required this.notificacionesGuardia,
    this.guardiaAsignado,
    this.mensaje,
    this.notificadaGuardiaEn,
    this.ultimaNotificacionUsuarioEn,
    this.respondidaPorGuardiaEn,
    this.enCaminoEn,
    this.resueltaEn,
    this.notaCierreCentral,
    this.segundosParaNotificarGuardia,
    this.guardiasAsignados = const [],
  });

  final String id;
  final String tipo;
  final String estado;
  final String? mensaje;
  final BicicleteroApp bicicletero;
  final UsuarioApp solicitante;
  final UsuarioApp? guardiaAsignado;
  final List<UsuarioApp> guardiasAsignados;
  final DateTime creadaEn;
  final DateTime? notificadaGuardiaEn;
  final DateTime? ultimaNotificacionUsuarioEn;
  final int notificacionesGuardia;
  final DateTime? respondidaPorGuardiaEn;
  final DateTime? enCaminoEn;
  final DateTime? resueltaEn;
  final String? notaCierreCentral;
  final bool puedeNotificarGuardia;
  final int? segundosParaNotificarGuardia;

  factory SolicitudGuardiaApp.desdeJson(Map<String, dynamic> json) {
    final guardia = json['guardiaAsignado'] as Map<String, dynamic>?;
    final guardias = json['guardiasAsignados'] as List<dynamic>? ?? const [];

    return SolicitudGuardiaApp(
      id: json['id'] as String,
      tipo: json['tipo'] as String,
      estado: json['estado'] as String,
      mensaje: json['mensaje'] as String?,
      bicicletero: BicicleteroApp.desdeJson(
        json['bicicletero'] as Map<String, dynamic>,
      ),
      solicitante: UsuarioApp.desdeJson(
        json['solicitante'] as Map<String, dynamic>,
      ),
      guardiaAsignado: guardia == null ? null : UsuarioApp.desdeJson(guardia),
      guardiasAsignados: guardias
          .whereType<Map<String, dynamic>>()
          .map(UsuarioApp.desdeJson)
          .toList(),
      creadaEn: DateTime.parse(json['creadaEn'] as String),
      notificadaGuardiaEn: json['notificadaGuardiaEn'] == null
          ? null
          : DateTime.parse(json['notificadaGuardiaEn'] as String),
      ultimaNotificacionUsuarioEn: json['ultimaNotificacionUsuarioEn'] == null
          ? null
          : DateTime.parse(json['ultimaNotificacionUsuarioEn'] as String),
      notificacionesGuardia: json['notificacionesGuardia'] as int? ?? 0,
      respondidaPorGuardiaEn: json['respondidaPorGuardiaEn'] == null
          ? null
          : DateTime.parse(json['respondidaPorGuardiaEn'] as String),
      enCaminoEn: json['enCaminoEn'] == null
          ? null
          : DateTime.parse(json['enCaminoEn'] as String),
      resueltaEn: json['resueltaEn'] == null
          ? null
          : DateTime.parse(json['resueltaEn'] as String),
      notaCierreCentral: json['notaCierreCentral'] as String?,
      puedeNotificarGuardia: json['puedeNotificarGuardia'] as bool? ?? false,
      segundosParaNotificarGuardia:
          json['segundosParaNotificarGuardia'] as int?,
    );
  }
}
