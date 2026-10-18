import 'package:ubbike/features/auth/data/autenticacion_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/providers/cliente_api_provider.dart';

class AutenticacionRepository {
  const AutenticacionRepository(this._api);

  final AutenticacionApi _api;

  Future<ResultadoLogin> iniciarSesion({
    required String correo,
    required String contrasena,
  }) =>
      _api.iniciarSesion(correo: correo, contrasena: contrasena);

  Future<ResultadoLogin> refrescarToken({
    required String usuarioId,
    required String refreshToken,
  }) =>
      _api.refrescarToken(usuarioId: usuarioId, refreshToken: refreshToken);

  Future<String> registrar({
    required String nombre,
    required String rut,
    required String correo,
    required String contrasena,
  }) =>
      _api.registrar(
        nombre: nombre,
        rut: rut,
        correo: correo,
        contrasena: contrasena,
      );

  Future<String> solicitarCambioContrasena(String correo) =>
      _api.solicitarCambioContrasena(correo);

  Future<ResultadoVerificacionCorreo> verificarCorreo(String token) =>
      _api.verificarCorreo(token);

  Future<String> completarRegistro({
    required String token,
    required String nombre,
    required String contrasena,
  }) =>
      _api.completarRegistro(
        token: token,
        nombre: nombre,
        contrasena: contrasena,
      );

  Future<String> cambiarContrasena({
    required String token,
    required String contrasena,
  }) =>
      _api.cambiarContrasena(token: token, contrasena: contrasena);

  Future<String> cambiarContrasenaSesion({
    required String contrasenaActual,
    required String contrasenaNueva,
  }) =>
      _api.cambiarContrasenaSesion(
        contrasenaActual: contrasenaActual,
        contrasenaNueva: contrasenaNueva,
      );
}

final autenticacionRepositoryProvider =
    Provider<AutenticacionRepository>((ref) {
  final cliente = ref.watch(clienteApiProvider);
  return AutenticacionRepository(AutenticacionApi(cliente: cliente));
});
