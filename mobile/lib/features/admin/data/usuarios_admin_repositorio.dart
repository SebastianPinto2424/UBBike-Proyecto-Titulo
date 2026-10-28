import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/features/admin/data/usuarios_admin_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/providers/cliente_api_provider.dart';

class UsuariosAdminRepositorio {
  const UsuariosAdminRepositorio(this._api);

  final UsuariosAdminApi _api;

  Future<List<UsuarioApp>> listarUsuarios({
    String? q,
    RolUsuario? rol,
    bool? cuentaActiva,
    bool? correoVerificado,
  }) =>
      _api.listarUsuarios(
        q: q,
        rol: rol,
        cuentaActiva: cuentaActiva,
        correoVerificado: correoVerificado,
      );

  Future<UsuarioApp> crearUsuario({
    required String nombre,
    required String correo,
    required RolUsuario rol,
    String? rut,
  }) =>
      _api.crearUsuario(
        nombre: nombre,
        correo: correo,
        rol: rol,
        rut: rut,
      );

  Future<UsuarioApp> actualizarPermisos({
    required String usuarioId,
    String? nombre,
    String? correo,
    String? rut,
    RolUsuario? rol,
    bool? cuentaActiva,
  }) =>
      _api.actualizarPermisos(
        usuarioId: usuarioId,
        nombre: nombre,
        correo: correo,
        rut: rut,
        rol: rol,
        cuentaActiva: cuentaActiva,
      );

  Future<void> reenviarVerificacion(String usuarioId) =>
      _api.reenviarVerificacion(usuarioId);

  Future<void> reenviarAcceso(String usuarioId) =>
      _api.reenviarAcceso(usuarioId);

  Future<void> eliminarUsuario(String usuarioId) =>
      _api.eliminarUsuario(usuarioId);
}

final usuariosAdminRepositorioProvider =
    Provider<UsuariosAdminRepositorio>((ref) {
  final cliente = ref.watch(clienteApiProvider);
  return UsuariosAdminRepositorio(UsuariosAdminApi(cliente: cliente));
});
