import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';

class ResultadoInicioSesion {
  const ResultadoInicioSesion(
      {required this.token, required this.usuario, this.refreshToken});

  final String token;
  final String? refreshToken;
  final UsuarioApp usuario;
}

class AutenticacionApi {
  const AutenticacionApi({required this.cliente});

  final ClienteApi cliente;

  Future<ResultadoInicioSesion> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final respuesta = await cliente.post(
      '/autenticacion/login',
      body: {'correo': correo, 'contrasena': contrasena},
    );

    return ResultadoInicioSesion(
      token: respuesta['token'] as String,
      refreshToken: respuesta['refreshToken'] as String?,
      usuario:
          UsuarioApp.fromJson(respuesta['usuario'] as Map<String, dynamic>),
    );
  }

  Future<ResultadoInicioSesion> refrescarToken({
    required String usuarioId,
    required String refreshToken,
  }) async {
    final respuesta = await cliente.post(
      '/autenticacion/refresh',
      body: {'usuarioId': usuarioId, 'refreshToken': refreshToken},
    );

    return ResultadoInicioSesion(
      token: respuesta['token'] as String,
      refreshToken: respuesta['refreshToken'] as String?,
      usuario: UsuarioApp.fromJson({}),
    );
  }

  Future<String> registrar({
    required String nombre,
    required String rut,
    required String correo,
    required String contrasena,
  }) async {
    final respuesta = await cliente.post(
      '/autenticacion/registro',
      body: {
        'nombre': nombre,
        'rut': rut,
        'correo': correo,
        'contrasena': contrasena
      },
    );
    return respuesta['message'] as String;
  }

  Future<String> solicitarCambioContrasena(String correo) async {
    final respuesta = await cliente.post(
      '/autenticacion/solicitar-cambio-contrasena',
      body: {'correo': correo},
    );
    return respuesta['message'] as String;
  }

  Future<String> reenviarVerificacion(String correo) async {
    final respuesta = await cliente.post(
      '/autenticacion/reenviar-verificacion',
      body: {'correo': correo},
    );
    return respuesta['message'] as String;
  }

  Future<String> cambiarContrasenaSesion({
    required String contrasenaActual,
    required String contrasenaNueva,
  }) async {
    final respuesta = await cliente.post(
      '/autenticacion/cambiar-contrasena-sesion',
      body: {
        'contrasenaActual': contrasenaActual,
        'contrasenaNueva': contrasenaNueva,
      },
    );
    return respuesta['message'] as String;
  }
}
