import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/core/servicios/cliente_api.dart';

class SesionApi {
  const SesionApi({required this.cliente});

  final ClienteApi cliente;

  Future<UsuarioApp> obtenerPerfil() async {
    final respuesta = await cliente.get('/autenticacion/yo');
    return UsuarioApp.fromJson(respuesta['usuario'] as Map<String, dynamic>);
  }

  Future<void> cerrarSesion({String? refreshToken}) async {
    try {
      await cliente.post(
        '/autenticacion/logout',
        body: refreshToken != null ? {'refreshToken': refreshToken} : {},
      );
    } catch (_) {}
  }
}
