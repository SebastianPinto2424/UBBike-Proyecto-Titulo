import 'package:flutter_test/flutter_test.dart';

import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/features/historial/presentation/exportacion_reporte.dart';

MovimientoApp _movimiento({
  String? marca,
  String? guardiaCorreo = 'guardia@ubiobio.cl',
}) =>
    MovimientoApp(
      id: 'mov-1',
      tipo: 'INGRESO',
      estado: 'CONFIRMADO',
      origen: 'QR',
      creadoEn: DateTime(2026, 9, 23, 16, 35),
      usuarioNombre: 'Sebastián Alexander Pinto Rivera',
      usuarioCorreo: 'sebastian.pinto2301@alumnos.ubiobio.cl',
      usuarioRut: '21.581.351-7',
      bicicletaDescripcion: 'bicicleta de hombre',
      bicicletaMarca: marca,
      bicicletaModelo: 'mtb',
      bicicletaColor: 'Amarillo',
      bicicletaAro: '27.5',
      bicicletaNumeroSerie: '182929RTG',
      bicicleteroNombre: 'Bicicletero cercano a la FACE',
      guardiaNombre: 'Esmeralda Caroline Pinto Rivera',
      guardiaCorreo: guardiaCorreo,
    );

void main() {
  test('cada fila tiene exactamente una celda por encabezado', () {
    final fila = filaReporte(_movimiento(marca: 'Oxford'));

    expect(fila.length, encabezadosReporte.length);
  });

  test('fecha y hora van en columnas separadas', () {
    final fila = filaReporte(_movimiento(marca: 'Oxford'));

    expect(fila[encabezadosReporte.indexOf('Fecha')], contains('23'));
    expect(fila[encabezadosReporte.indexOf('Hora')], contains('16:35'));
  });

  test('la ficha de la bicicleta va junta en una celda', () {
    final fila = filaReporte(_movimiento(marca: 'Oxford'));
    final detalle = fila[encabezadosReporte.indexOf('Detalle bicicleta')];

    expect(detalle, 'Oxford · mtb · Amarillo · aro 27.5');
  });

  test('los datos faltantes no dejan la celda vacía', () {
    final fila = filaReporte(_movimiento(marca: null, guardiaCorreo: null));

    expect(fila[encabezadosReporte.indexOf('Detalle bicicleta')],
        'mtb · Amarillo · aro 27.5');
    expect(fila[encabezadosReporte.indexOf('Correo guardia')], '-');
    expect(fila.every((celda) => celda.isNotEmpty), isTrue);
  });

  test('el reporte sigue incluyendo la ficha del guardia', () {
    for (final titulo in [
      'Detalle bicicleta',
      'N° de serie',
      'Guardia',
      'Correo guardia',
    ]) {
      expect(encabezadosReporte, contains(titulo));
    }
  });

  test('entra en A4: no más de 14 columnas', () {
    expect(encabezadosReporte.length, lessThanOrEqualTo(14));
  });

  test('las columnas solo del Excel no se repiten en la tabla', () {
    for (final extra in columnasSoloExcel) {
      expect(encabezadosReporte, isNot(contains(extra)));
    }
  });
}
