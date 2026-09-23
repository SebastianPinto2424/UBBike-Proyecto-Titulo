class ExcepcionApi implements Exception {
  const ExcepcionApi(this.mensaje, {this.statusCode});

  final String mensaje;
  final int? statusCode;

  @override
  String toString() => mensaje;
}
