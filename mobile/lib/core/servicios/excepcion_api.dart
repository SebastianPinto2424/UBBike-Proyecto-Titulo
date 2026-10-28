const mensajeSinConexion =
    'No pudimos conectar con el servidor. Revisa tu conexión e intenta nuevamente.';

const mensajeServidorNoDisponible =
    'El servidor no responde en este momento. Intenta nuevamente en unos minutos.';

class ExcepcionApi implements Exception {
  const ExcepcionApi(this.mensaje, {this.statusCode, this.codigo});

  final String mensaje;
  final int? statusCode;
  final String? codigo;

  @override
  String toString() => mensaje;
}
