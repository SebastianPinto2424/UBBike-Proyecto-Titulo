import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

class BicicleterosAdminApi {
  const BicicleterosAdminApi({required this.cliente});

  final ClienteApi cliente;

  Future<List<BicicleteroApp>> listar() async {
    final respuesta = await cliente.get('/bicicleteros');
    final datos = respuesta['bicicleteros'] as List<dynamic>;
    return datos
        .map((item) => BicicleteroApp.desdeJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<BicicleteroApp> crear({
    required String nombre,
    required String ubicacion,
    required int capacidad,
    double? latitud,
    double? longitud,
  }) async {
    final respuesta = await cliente.post(
      '/bicicleteros',
      body: {
        'nombre': nombre,
        'ubicacion': ubicacion,
        'capacidad': capacidad,
        if (latitud != null) 'latitud': latitud,
        if (longitud != null) 'longitud': longitud,
      },
    );

    return BicicleteroApp.desdeJson(
      respuesta['bicicletero'] as Map<String, dynamic>,
    );
  }

  Future<BicicleteroApp> actualizar({
    required String bicicleteroId,
    required String nombre,
    required String ubicacion,
    required int capacidad,
    double? latitud,
    double? longitud,
  }) async {
    final respuesta = await cliente.patch(
      '/bicicleteros/$bicicleteroId',
      body: {
        'nombre': nombre,
        'ubicacion': ubicacion,
        'capacidad': capacidad,
        'latitud': latitud,
        'longitud': longitud,
      },
    );

    return BicicleteroApp.desdeJson(
      respuesta['bicicletero'] as Map<String, dynamic>,
    );
  }

  Future<void> eliminar(String bicicleteroId) async {
    await cliente.delete('/bicicleteros/$bicicleteroId');
  }
}
