import 'package:ubbike/shared/modelos/movimiento_app.dart';

class ResumenGuardia {
  int total = 0;
  int denegaciones = 0;
  final bicicleteros = <String>{};
}

Map<String, ResumenGuardia> agruparPorGuardia(
  List<MovimientoApp> movimientos,
) {
  final resumen = <String, ResumenGuardia>{};

  for (final movimiento in movimientos) {
    final guardia = resumen.putIfAbsent(
      movimiento.guardiaNombre,
      ResumenGuardia.new,
    );

    guardia.total += 1;
    if (movimiento.estado == 'DENEGADO') {
      guardia.denegaciones += 1;
    }
    guardia.bicicleteros.add(movimiento.bicicleteroNombre);
  }

  return resumen;
}
