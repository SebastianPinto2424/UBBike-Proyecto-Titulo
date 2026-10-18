import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/auth/data/autenticacion_repository.dart';
import 'package:ubbike/features/auth/data/autenticacion_api.dart';

class AutenticacionVm {
  const AutenticacionVm(this._ref);

  final Ref _ref;

  Future<ResultadoLogin> iniciarSesion({
    required String correo,
    required String contrasena,
  }) =>
      _ref.read(autenticacionRepositoryProvider).iniciarSesion(
            correo: correo,
            contrasena: contrasena,
          );

  Future<String> registrar({
    required String nombre,
    required String rut,
    required String correo,
    required String contrasena,
  }) =>
      _ref.read(autenticacionRepositoryProvider).registrar(
            nombre: nombre,
            rut: rut,
            correo: correo,
            contrasena: contrasena,
          );

  Future<String> solicitarCambioContrasena(String correo) => _ref
      .read(autenticacionRepositoryProvider)
      .solicitarCambioContrasena(correo);

  Future<ResultadoVerificacionCorreo> verificarCorreo(String token) =>
      _ref.read(autenticacionRepositoryProvider).verificarCorreo(token);

  Future<String> completarRegistro({
    required String token,
    required String nombre,
    required String contrasena,
  }) =>
      _ref.read(autenticacionRepositoryProvider).completarRegistro(
            token: token,
            nombre: nombre,
            contrasena: contrasena,
          );

  Future<String> cambiarContrasena({
    required String token,
    required String contrasena,
  }) =>
      _ref.read(autenticacionRepositoryProvider).cambiarContrasena(
            token: token,
            contrasena: contrasena,
          );

  Future<String> cambiarContrasenaSesion({
    required String contrasenaActual,
    required String contrasenaNueva,
  }) =>
      _ref.read(autenticacionRepositoryProvider).cambiarContrasenaSesion(
            contrasenaActual: contrasenaActual,
            contrasenaNueva: contrasenaNueva,
          );
}

final autenticacionVmProvider = Provider.autoDispose<AutenticacionVm>(
  (ref) => AutenticacionVm(ref),
);
