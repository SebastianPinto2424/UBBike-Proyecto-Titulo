import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';

class ResultadoLogin {
  const ResultadoLogin(
      {required this.token, required this.usuario, this.refreshToken});

  final String token;
  final String? refreshToken;
  final UsuarioApp usuario;
}

class ResultadoVerificacionCorreo {
  const ResultadoVerificacionCorreo({required this.mensaje, this.correo});

  final String mensaje;
  final String? correo;
}

class AutenticacionApi {
  const AutenticacionApi({required this.cliente});

  final ClienteApi cliente;

  Future<ResultadoLogin> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final respuesta = await cliente.post(
      '/autenticacion/login',
      body: {'correo': correo, 'contrasena': contrasena},
    );

    return ResultadoLogin(
      token: respuesta['token'] as String,
      refreshToken: respuesta['refreshToken'] as String?,
      usuario:
          UsuarioApp.fromJson(respuesta['usuario'] as Map<String, dynamic>),
    );
  }

  Future<ResultadoLogin> refrescarToken({
    required String usuarioId,
    required String refreshToken,
  }) async {
    final respuesta = await cliente.post(
      '/autenticacion/refresh',
      body: {'usuarioId': usuarioId, 'refreshToken': refreshToken},
    );

    return ResultadoLogin(
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

  Future<ResultadoVerificacionCorreo> verificarCorreo(String token) async {
    final respuesta = await cliente.post(
      '/autenticacion/verificar-correo',
      body: {'token': token},
    );
    final usuario = respuesta['usuario'] as Map<String, dynamic>?;

    return ResultadoVerificacionCorreo(
      mensaje: respuesta['message'] as String,
      correo: usuario?['correo'] as String?,
    );
  }

  Future<String> completarRegistro({
    required String token,
    required String nombre,
    required String contrasena,
  }) async {
    final respuesta = await cliente.post(
      '/autenticacion/completar-registro',
      body: {'token': token, 'nombre': nombre, 'contrasena': contrasena},
    );
    return respuesta['message'] as String;
  }

  Future<String> cambiarContrasena({
    required String token,
    required String contrasena,
  }) async {
    final respuesta = await cliente.post(
      '/autenticacion/cambiar-contrasena',
      body: {'token': token, 'contrasena': contrasena},
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
