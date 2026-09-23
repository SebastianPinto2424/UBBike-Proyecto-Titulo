class PuntoGeografico {
  const PuntoGeografico(this.latitud, this.longitud);

  final double latitud;
  final double longitud;

  bool get esValido =>
      latitud.isFinite &&
      longitud.isFinite &&
      latitud >= -90 &&
      latitud <= 90 &&
      longitud >= -180 &&
      longitud <= 180;

  static PuntoGeografico? desdeTexto(String latitud, String longitud) {
    final lat = double.tryParse(latitud.trim().replaceAll(',', '.'));
    final lng = double.tryParse(longitud.trim().replaceAll(',', '.'));
    if (lat == null || lng == null) return null;
    final punto = PuntoGeografico(lat, lng);
    return punto.esValido ? punto : null;
  }

  String get etiqueta =>
      '${latitud.toStringAsFixed(6)}, ${longitud.toStringAsFixed(6)}';
}
