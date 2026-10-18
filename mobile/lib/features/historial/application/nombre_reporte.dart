String nombreArchivoReporte(DateTime momento, String extension) {
  String dosDigitos(int valor) => valor.toString().padLeft(2, '0');

  final fecha = '${momento.year}-${dosDigitos(momento.month)}-'
      '${dosDigitos(momento.day)}';
  final hora = '${dosDigitos(momento.hour)}-${dosDigitos(momento.minute)}';
  return 'historial-ubbike-${fecha}_$hora.$extension';
}
