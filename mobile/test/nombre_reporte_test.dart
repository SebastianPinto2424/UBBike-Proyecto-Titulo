import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/features/historial/application/nombre_reporte.dart';

void main() {
  test('usa la fecha ISO y la hora, con ceros a la izquierda', () {
    expect(
      nombreArchivoReporte(DateTime(2026, 3, 5, 9, 7), 'xlsx'),
      'historial-ubbike-2026-03-05_09-07.xlsx',
    );
    expect(
      nombreArchivoReporte(DateTime(2026, 10, 16, 15, 30), 'pdf'),
      'historial-ubbike-2026-10-16_15-30.pdf',
    );
  });
}
