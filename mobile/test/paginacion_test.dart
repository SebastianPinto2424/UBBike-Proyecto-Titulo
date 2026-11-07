import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ubbike/core/providers/cliente_api_provider.dart';
import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/features/incidencias/application/incidencias_vm.dart';
import 'package:ubbike/features/notificaciones/application/controlador_notificaciones.dart';
import 'package:ubbike/features/notificaciones/data/notificacion_api.dart';
import 'package:ubbike/features/notificaciones/data/notificacion_repositorio.dart';

Map<String, Object> incidencia(int i) => {
      'id': '$i',
      'tipo': 'OTRO',
      'descripcion': 'Reporte $i',
      'estado': 'PENDIENTE',
      'creadaEn': '2026-09-14T12:00:00Z',
      'actualizadaEn': '2026-09-14T12:00:00Z',
      'bicicletero': {'id': 'rack', 'nombre': 'FACE'},
      'reportadaPorUsuario': {'id': 'u'}
    };
void main() {
  test(
      'carga más incidencias sin duplicar y conserva páginas durante el refresco',
      () async {
    final c = ProviderContainer(overrides: [
      clienteApiProvider
          .overrideWithValue(ClienteApi(cliente: MockClient((r) async {
        final segunda = r.url.queryParameters['cursor'] == '19';
        return http.Response(
            jsonEncode({
              'incidencias':
                  List.generate(20, (i) => incidencia(segunda ? i + 20 : i)),
              'nextCursor': segunda ? null : '19'
            }),
            200);
      })))
    ]);
    addTearDown(c.dispose);
    c.listen(incidenciasVmProvider, (_, __) {});
    expect(await c.read(incidenciasVmProvider.future), hasLength(20));
    final vm = c.read(incidenciasVmProvider.notifier);
    await Future.wait([vm.cargarMas(), vm.cargarMas()]);
    expect(c.read(incidenciasVmProvider).requireValue, hasLength(40));
    expect(vm.hayMas, false);
    await vm.refrescar();
    expect(c.read(incidenciasVmProvider).requireValue, hasLength(40));
    vm.cambiarEstado('ABIERTAS');
    await c.read(incidenciasVmProvider.future);
    expect(c.read(incidenciasVmProvider).requireValue, hasLength(20));
  });
  test('contador de notificaciones usa el total servidor, no la página visible',
      () async {
    var leidas = false;
    final cliente = ClienteApi(cliente: MockClient((r) async {
      if (r.method == 'PATCH') {
        leidas = true;
        return http.Response('{}', 200);
      }
      return http.Response(
          jsonEncode({
            'notificaciones': [],
            'nextCursor': 'pagina2',
            'noLeidas': leidas ? 0 : 150
          }),
          200);
    }));
    final controlador = ControladorNotificaciones(
        notificacionRepositorio:
            NotificacionRepositorio(NotificacionApi(cliente: cliente)));
    addTearDown(controlador.dispose);
    await controlador.actualizar();
    expect(controlador.noLeidas, 150);
    await controlador.marcarTodasLeidas();
    expect(controlador.noLeidas, 0);
  });
}
