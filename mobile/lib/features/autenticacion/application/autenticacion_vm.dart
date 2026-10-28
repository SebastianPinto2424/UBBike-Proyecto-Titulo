import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/autenticacion/data/autenticacion_repositorio.dart';
import 'package:ubbike/features/autenticacion/data/autenticacion_api.dart';

class AutenticacionVm {
  const AutenticacionVm(this._ref);

  final Ref _ref;

  Future<ResultadoInicioSesion> iniciarSesion({
    required String correo,
    required String contrasena,
  }) =>
      _ref.read(autenticacionRepositorioProvider).iniciarSesion(
            correo: correo,
            contrasena: contrasena,
          );

  Future<String> registrar({
    required String nombre,
    required String rut,
    required String correo,
    required String contrasena,
  }) =>
      _ref.read(autenticacionRepositorioProvider).registrar(
            nombre: nombre,
            rut: rut,
            correo: correo,
            contrasena: contrasena,
          );

  Future<String> solicitarCambioContrasena(String correo) => _ref
      .read(autenticacionRepositorioProvider)
      .solicitarCambioContrasena(correo);

  Future<String> reenviarVerificacion(String correo) =>
      _ref.read(autenticacionRepositorioProvider).reenviarVerificacion(correo);

  Future<String> cambiarContrasenaSesion({
    required String contrasenaActual,
    required String contrasenaNueva,
  }) =>
      _ref.read(autenticacionRepositorioProvider).cambiarContrasenaSesion(
            contrasenaActual: contrasenaActual,
            contrasenaNueva: contrasenaNueva,
          );
}

final autenticacionVmProvider = Provider.autoDispose<AutenticacionVm>(
  (ref) => AutenticacionVm(ref),
);
