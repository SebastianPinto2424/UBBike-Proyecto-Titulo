import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ubbike/core/providers/cliente_api_provider.dart';
import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/features/inicio/application/tablero_central_vm.dart';
import 'package:ubbike/features/inicio/application/tablero_administrador_vm.dart';
import 'package:ubbike/features/incidencias/application/incidencias_vm.dart';
import 'package:ubbike/features/historial/application/movimientos_vm.dart';

void main() {
  late ProviderContainer c;
  var fallar = false;
  setUp(() {
    fallar = false;
    c = ProviderContainer(overrides: [
      clienteApiProvider
          .overrideWithValue(ClienteApi(cliente: MockClient((r) async {
        if (fallar) return http.Response('{}', 503);
        final json = switch (r.url.path) {
          '/historial/resumen' => {
              'resumen': {'incidenciasAbiertas': 450, 'usuariosActivos': 7}
            },
          '/historial' => {'movimientos': []},
          '/bicicleteros' => {'bicicleteros': []},
          '/incidencias' => {'incidencias': [], 'nextCursor': null},
          _ => throw StateError('Petición inesperada: ${r.url}'),
        };
        return http.Response(jsonEncode(json), 200);
      })))
    ]);
  });
  tearDown(() => c.dispose());
  test('cambiar períodos de ambos tableros no reasigna un late final',
      () async {
    c.listen(tableroCentralVmProvider, (_, __) {});
    c.listen(tableroAdministradorVmProvider, (_, __) {});
    await c.read(tableroCentralVmProvider.future);
    await c.read(tableroAdministradorVmProvider.future);
    for (final periodo in ['DIA', 'MES', 'SEMANA']) {
      c.read(tableroCentralVmProvider.notifier).cambiarPeriodo(periodo);
      c.read(tableroAdministradorVmProvider.notifier).cambiarPeriodo(periodo);
      expect(
          (await c.read(tableroCentralVmProvider.future))
              .totalIncidenciasAbiertas,
          450);
      expect(
          (await c.read(tableroAdministradorVmProvider.future)).usuariosActivos,
          7);
    }
  });
  test(
      'cambiar filtros e invalidar incidencias e historial permite seguir refrescando',
      () async {
    c.listen(incidenciasVmProvider, (_, __) {});
    c.listen(movimientosUsuarioVmProvider, (_, __) {});
    await c.read(incidenciasVmProvider.future);
    await c.read(movimientosUsuarioVmProvider.future);
    for (final estado in ['PENDIENTE', 'ABIERTAS', 'RESUELTA']) {
      c.read(incidenciasVmProvider.notifier).cambiarEstado(estado);
      c.read(filtrosMovimientosUsuarioProvider.notifier).state =
          FiltrosMovimientosUsuario(estado: estado);
      expect(await c.read(incidenciasVmProvider.future), isEmpty);
      expect(await c.read(movimientosUsuarioVmProvider.future), isEmpty);
    }
    c.invalidate(incidenciasVmProvider);
    await c.read(incidenciasVmProvider.future);
    await c.read(incidenciasVmProvider.notifier).refrescar();
  });
  test('una caída temporal conserva el tablero y lo marca desactualizado',
      () async {
    c.listen(tableroCentralVmProvider, (_, __) {});
    await c.read(tableroCentralVmProvider.future);
    fallar = true;
    await c.read(tableroCentralVmProvider.notifier).refrescar();
    final datos = c.read(tableroCentralVmProvider).requireValue;
    expect(datos.totalIncidenciasAbiertas, 450);
    expect(datos.desactualizado, true);
  });
}
