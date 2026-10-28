import 'package:ubbike/features/autenticacion/data/autenticacion_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/providers/cliente_api_provider.dart';

class AutenticacionRepositorio {
  const AutenticacionRepositorio(this._api);

  final AutenticacionApi _api;

  Future<ResultadoInicioSesion> iniciarSesion({
    required String correo,
    required String contrasena,
  }) =>
      _api.iniciarSesion(correo: correo, contrasena: contrasena);

  Future<ResultadoInicioSesion> refrescarToken({
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

  Future<String> reenviarVerificacion(String correo) =>
      _api.reenviarVerificacion(correo);

  Future<String> cambiarContrasenaSesion({
    required String contrasenaActual,
    required String contrasenaNueva,
  }) =>
      _api.cambiarContrasenaSesion(
        contrasenaActual: contrasenaActual,
        contrasenaNueva: contrasenaNueva,
      );
}

final autenticacionRepositorioProvider =
    Provider<AutenticacionRepositorio>((ref) {
  final cliente = ref.watch(clienteApiProvider);
  return AutenticacionRepositorio(AutenticacionApi(cliente: cliente));
});
