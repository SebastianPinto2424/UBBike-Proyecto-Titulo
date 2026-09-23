class MovimientoApp {
  const MovimientoApp({
    required this.id,
    required this.tipo,
    required this.estado,
    required this.origen,
    required this.creadoEn,
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
    required this.bicicleteroNombre,
    required this.guardiaNombre,
    this.guardiaCorreo,
    this.motivoDenegacion,
    this.comentarioGuardia,
  });

  final String id;
  final String tipo;
  final String estado;
  final String origen;
  final DateTime creadoEn;
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
  final String bicicleteroNombre;
  final String guardiaNombre;
  final String? guardiaCorreo;
  final String? motivoDenegacion;
  final String? comentarioGuardia;

  factory MovimientoApp.desdeJson(Map<String, dynamic> json) {
    final usuario = json['usuario'] as Map<String, dynamic>;
    final bicicleta = json['bicicleta'] as Map<String, dynamic>;
    final bicicletero = json['bicicletero'] as Map<String, dynamic>;
    final guardia = json['guardia'] as Map<String, dynamic>;

    return MovimientoApp(
      id: json['id'] as String,
      tipo: json['tipo'] as String,
      estado: json['estado'] as String,
      origen: json['origen'] as String,
      creadoEn: DateTime.parse(json['creadoEn'] as String),
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
      bicicleteroNombre: bicicletero['nombre'] as String,
      guardiaNombre: guardia['nombre'] as String,
      guardiaCorreo: guardia['correo'] as String?,
      motivoDenegacion: json['motivoDenegacion'] as String?,
      comentarioGuardia: json['comentarioGuardia'] as String?,
    );
  }
}
