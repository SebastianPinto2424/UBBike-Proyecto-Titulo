import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/features/admin/data/bicicleteros_admin_api.dart';
import 'package:ubbike/features/admin/data/bicicleteros_admin_repositorio.dart';

void main() {
  for (final quitar in [false, true]) {
    test(
        'repositorio/API ${quitar ? 'elimina' : 'guarda'} el punto con los nombres del contrato',
        () async {
      late http.Request enviada;
      final cliente = ClienteApi(
          obtenerToken: () => 'jwt-prueba',
          cliente: MockClient((r) async {
            enviada = r;
            return http.Response(
                jsonEncode({
                  'bicicletero': {'id': 'rack', ...jsonDecode(r.body)}
                }),
                200);
          }));
      final repo =
          BicicleterosAdminRepositorio(BicicleterosAdminApi(cliente: cliente));
      final resultado = await repo.actualizar(
          bicicleteroId: 'rack',
          nombre: 'FACE',
          ubicacion: 'Acceso principal',
          capacidad: 80,
          latitud: quitar ? null : -36.82,
          longitud: quitar ? null : -73.01);
      expect(enviada.method, 'PATCH');
      expect(enviada.url.path, endsWith('/bicicleteros/rack'));
      final body = jsonDecode(enviada.body) as Map<String, dynamic>;
      expect(body.containsKey('latitud'), isTrue);
      expect(body.containsKey('longitud'), isTrue);
      expect(body['latitud'], quitar ? null : -36.82);
      expect(body['longitud'], quitar ? null : -73.01);
      expect(resultado.tieneCoordenadas, !quitar);
    });
  }
}
