import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

class BicicleterosApi {
  const BicicleterosApi({required this.cliente});

  final ClienteApi cliente;

  Future<List<BicicleteroApp>> listar() async {
    final respuesta = await cliente.get('/bicicleteros');
    final datos = respuesta['bicicleteros'] as List<dynamic>;
    return datos
        .map((item) => BicicleteroApp.desdeJson(item as Map<String, dynamic>))
        .toList();
  }
}
