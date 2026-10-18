import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';

class FotoIncidenciaApp {
  const FotoIncidenciaApp({
    required this.id,
    required this.url,
    required this.mimeType,
    required this.tamanoBytes,
  });

  final String id;
  final String url;
  final String mimeType;
  final int tamanoBytes;

  factory FotoIncidenciaApp.desdeJson(Map<String, dynamic> json) {
    return FotoIncidenciaApp(
      id: json['id'] as String,
      url: json['url'] as String,
      mimeType: json['mimeType'] as String? ?? 'image/jpeg',
      tamanoBytes: json['tamanoBytes'] as int? ?? 0,
    );
  }
}

class IncidenciaApp {
  const IncidenciaApp({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.estado,
    required this.creadaEn,
    required this.actualizadaEn,
    required this.bicicletero,
    required this.reportadaPorUsuario,
    required this.recordatorios,
    required this.puedeRecordar,
    this.fotos = const <FotoIncidenciaApp>[],
    this.segundosParaRecordar,
    this.bicicleta,
    this.gestionadaPorUsuario,
    this.respuesta,
    this.resueltaEn,
    this.ultimoRecordatorioEn,
  });

  final String id;
  final String tipo;
  final String descripcion;
  final String estado;
  final String? respuesta;
  final DateTime creadaEn;
  final DateTime actualizadaEn;
  final DateTime? resueltaEn;
  final DateTime? ultimoRecordatorioEn;
  final int recordatorios;
  final bool puedeRecordar;
  final int? segundosParaRecordar;
  final BicicleteroApp bicicletero;
  final BicicletaApp? bicicleta;
  final UsuarioApp reportadaPorUsuario;
  final UsuarioApp? gestionadaPorUsuario;
  final List<FotoIncidenciaApp> fotos;

  factory IncidenciaApp.desdeJson(Map<String, dynamic> json) {
    final bicicleta = json['bicicleta'] as Map<String, dynamic>?;
    final gestionadaPorUsuario =
        json['gestionadaPorUsuario'] as Map<String, dynamic>?;

    return IncidenciaApp(
      id: json['id'] as String,
      tipo: json['tipo'] as String,
      descripcion: json['descripcion'] as String,
      estado: json['estado'] as String,
      respuesta: json['respuesta'] as String?,
      creadaEn: DateTime.parse(json['creadaEn'] as String),
      actualizadaEn: DateTime.parse(json['actualizadaEn'] as String),
      resueltaEn: json['resueltaEn'] == null
          ? null
          : DateTime.parse(json['resueltaEn'] as String),
      ultimoRecordatorioEn: json['ultimoRecordatorioEn'] == null
          ? null
          : DateTime.parse(json['ultimoRecordatorioEn'] as String),
      recordatorios: json['recordatorios'] as int? ?? 0,
      puedeRecordar: json['puedeRecordar'] as bool? ?? false,
      segundosParaRecordar: json['segundosParaRecordar'] as int?,
      bicicletero: BicicleteroApp.desdeJson(
        json['bicicletero'] as Map<String, dynamic>,
      ),
      bicicleta: bicicleta == null ? null : BicicletaApp.desdeJson(bicicleta),
      reportadaPorUsuario: UsuarioApp.desdeJson(
        json['reportadaPorUsuario'] as Map<String, dynamic>,
      ),
      gestionadaPorUsuario: gestionadaPorUsuario == null
          ? null
          : UsuarioApp.desdeJson(gestionadaPorUsuario),
      fotos: (json['fotos'] as List<dynamic>? ?? const [])
          .map((item) =>
              FotoIncidenciaApp.desdeJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
