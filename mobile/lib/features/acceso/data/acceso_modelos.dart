import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';

class QrValidadoApp {
  const QrValidadoApp({
    required this.token,
    required this.tipo,
    required this.expiraEn,
    required this.usuarioNombre,
    required this.usuarioCorreo,
    required this.usuarioRut,
    required this.bicicletaDescripcion,
    this.bicicletaMarca,
    this.bicicletaModelo,
    this.bicicletaColor,
    this.bicicletaAro,
    this.bicicletaNumeroSerie,
    this.bicicletaFotoUrl,
    this.bicicleteroNombre,
  });

  final String token;
  final String tipo;
  final DateTime expiraEn;
  final String usuarioNombre;
  final String usuarioCorreo;
  final String? usuarioRut;
  final String bicicletaDescripcion;
  final String? bicicletaMarca;
  final String? bicicletaModelo;
  final String? bicicletaColor;
  final String? bicicletaAro;
  final String? bicicletaNumeroSerie;
  final String? bicicletaFotoUrl;
  final String? bicicleteroNombre;

  factory QrValidadoApp.desdeJson(Map<String, dynamic> json) {
    final usuario = json['usuario'] as Map<String, dynamic>;
    final bicicleta = json['bicicleta'] as Map<String, dynamic>;
    final bicicletero = json['bicicletero'] as Map<String, dynamic>?;

    return QrValidadoApp(
      token: json['token'] as String,
      tipo: json['tipo'] as String,
      expiraEn: DateTime.parse(json['expiraEn'] as String),
      usuarioNombre: usuario['nombre'] as String,
      usuarioCorreo: usuario['correo'] as String,
      usuarioRut: usuario['rut'] as String?,
      bicicletaDescripcion: bicicleta['descripcion'] as String,
      bicicletaMarca: bicicleta['marca'] as String?,
      bicicletaModelo: bicicleta['modelo'] as String?,
      bicicletaColor: bicicleta['color'] as String?,
      bicicletaAro: bicicleta['aro'] as String?,
      bicicletaNumeroSerie: bicicleta['numeroSerie'] as String?,
      bicicletaFotoUrl: bicicleta['fotoUrl'] as String?,
      bicicleteroNombre: bicicletero?['nombre'] as String?,
    );
  }
}

class CoincidenciaManualApp {
  const CoincidenciaManualApp({
    required this.usuario,
    required this.bicicletas,
  });

  final UsuarioApp usuario;
  final List<BicicletaApp> bicicletas;

  factory CoincidenciaManualApp.desdeJson(Map<String, dynamic> json) {
    final bicicletasJson = json['bicicletas'] as List<dynamic>? ?? const [];

    return CoincidenciaManualApp(
      usuario: UsuarioApp.desdeJson(json['usuario'] as Map<String, dynamic>),
      bicicletas: bicicletasJson
          .map((item) => BicicletaApp.desdeJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SolicitudRegistroManual {
  const SolicitudRegistroManual({
    required this.tipo,
    this.nombre,
    this.correo,
    this.rut,
    this.bicicletaId,
    this.bicicleteroId,
    this.denegar = false,
    this.motivo,
    this.comentario,
    this.bicicletaDescripcion,
    this.bicicletaMarca,
    this.bicicletaModelo,
    this.bicicletaColor,
    this.bicicletaAro,
    this.bicicletaNumeroSerie,
    this.bicicletaFotoUrl,
    this.crearBicicletaNueva = false,
  });

  final String tipo;
  final String? nombre;
  final String? correo;
  final String? rut;
  final String? bicicletaId;
  final String? bicicleteroId;
  final bool denegar;
  final String? motivo;
  final String? comentario;
  final String? bicicletaDescripcion;
  final String? bicicletaMarca;
  final String? bicicletaModelo;
  final String? bicicletaColor;
  final String? bicicletaAro;
  final String? bicicletaNumeroSerie;
  final String? bicicletaFotoUrl;
  final bool crearBicicletaNueva;

  Map<String, dynamic> aJson() {
    final opcionales = {
      'nombre': nombre,
      'correo': correo,
      'rut': rut,
      'bicicletaId': bicicletaId,
      'bicicleteroId': bicicleteroId,
      'comentario': comentario,
      'bicicletaDescripcion': bicicletaDescripcion,
      'bicicletaMarca': bicicletaMarca,
      'bicicletaModelo': bicicletaModelo,
      'bicicletaColor': bicicletaColor,
      'bicicletaAro': bicicletaAro,
      'bicicletaNumeroSerie': bicicletaNumeroSerie,
      'bicicletaFotoUrl': bicicletaFotoUrl,
    };
    return {
      for (final campo in opcionales.entries)
        if (campo.value != null && campo.value!.isNotEmpty)
          campo.key: campo.value,
      'tipo': tipo,
      'denegar': denegar,
      'motivo': motivo,
      'crearBicicletaNueva': crearBicicletaNueva,
    };
  }
}

class GuardiaTurnoApp {
  const GuardiaTurnoApp({
    required this.id,
    required this.nombre,
    this.bicicleteroId,
    this.bicicleteroNombre,
  });

  final String id;
  final String nombre;
  final String? bicicleteroId;
  final String? bicicleteroNombre;

  bool get enTurno => bicicleteroId != null;

  factory GuardiaTurnoApp.desdeJson(Map<String, dynamic> json) {
    final bicicletero = json['bicicletero'] as Map<String, dynamic>?;
    return GuardiaTurnoApp(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      bicicleteroId: bicicletero?['id'] as String?,
      bicicleteroNombre: bicicletero?['nombre'] as String?,
    );
  }
}
