import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/repositorios_provider.dart';
import 'package:ubbike/shared/modelos/rol_usuario.dart';
import 'package:ubbike/shared/modelos/usuario_app.dart';

final usuariosVersionProvider = StateProvider<int>((ref) => 0);

enum FiltroEstadoCuenta { todos, activos, denegados }

extension DatosFiltroEstadoCuenta on FiltroEstadoCuenta {
  String get etiqueta {
    switch (this) {
      case FiltroEstadoCuenta.todos:
        return 'Todos';
      case FiltroEstadoCuenta.activos:
        return 'Activos';
      case FiltroEstadoCuenta.denegados:
        return 'Acceso denegado';
    }
  }

  bool? get valor {
    switch (this) {
      case FiltroEstadoCuenta.todos:
        return null;
      case FiltroEstadoCuenta.activos:
        return true;
      case FiltroEstadoCuenta.denegados:
        return false;
    }
  }
}

enum FiltroEstadoCorreo { todos, verificados, pendientes }

extension DatosFiltroEstadoCorreo on FiltroEstadoCorreo {
  String get etiqueta {
    switch (this) {
      case FiltroEstadoCorreo.todos:
        return 'Todos';
      case FiltroEstadoCorreo.verificados:
        return 'Verificados';
      case FiltroEstadoCorreo.pendientes:
        return 'Pendientes';
    }
  }

  bool? get valor {
    switch (this) {
      case FiltroEstadoCorreo.todos:
        return null;
      case FiltroEstadoCorreo.verificados:
        return true;
      case FiltroEstadoCorreo.pendientes:
        return false;
    }
  }
}

class FiltrosGestionUsuarios {
  const FiltrosGestionUsuarios({
    this.busqueda = '',
    this.rol,
    this.estadoCuenta = FiltroEstadoCuenta.todos,
    this.estadoCorreo = FiltroEstadoCorreo.todos,
  });

  final String busqueda;
  final RolUsuario? rol;
  final FiltroEstadoCuenta estadoCuenta;
  final FiltroEstadoCorreo estadoCorreo;

  bool get tieneFiltros =>
      busqueda.isNotEmpty ||
      rol != null ||
      estadoCuenta != FiltroEstadoCuenta.todos ||
      estadoCorreo != FiltroEstadoCorreo.todos;

  FiltrosGestionUsuarios copyWith({
    String? busqueda,
    RolUsuario? rol,
    bool limpiarRol = false,
    FiltroEstadoCuenta? estadoCuenta,
    FiltroEstadoCorreo? estadoCorreo,
  }) {
    return FiltrosGestionUsuarios(
      busqueda: busqueda ?? this.busqueda,
      rol: limpiarRol ? null : (rol ?? this.rol),
      estadoCuenta: estadoCuenta ?? this.estadoCuenta,
      estadoCorreo: estadoCorreo ?? this.estadoCorreo,
    );
  }
}

final filtrosGestionUsuariosProvider =
    StateProvider.autoDispose<FiltrosGestionUsuarios>(
  (ref) => const FiltrosGestionUsuarios(),
);

class GestionUsuariosVm extends AutoDisposeAsyncNotifier<List<UsuarioApp>> {
  Timer? _debounceBusqueda;

  @override
  Future<List<UsuarioApp>> build() {
    final filtros = ref.watch(filtrosGestionUsuariosProvider);
    ref.onDispose(() => _debounceBusqueda?.cancel());

    final usuariosRepository = ref.read(usuariosAdminRepositoryProvider);
    return usuariosRepository.listarUsuarios(
      q: filtros.busqueda,
      rol: filtros.rol,
      cuentaActiva: filtros.estadoCuenta.valor,
      correoVerificado: filtros.estadoCorreo.valor,
    );
  }

  void recargar() {
    ref.invalidateSelf();
  }

  void buscar(String valor) {
    _debounceBusqueda?.cancel();
    _debounceBusqueda = Timer(const Duration(milliseconds: 350), () {
      final filtros = ref.read(filtrosGestionUsuariosProvider);
      ref.read(filtrosGestionUsuariosProvider.notifier).state =
          filtros.copyWith(busqueda: valor.trim());
    });
  }

  void actualizarFiltros({
    RolUsuario? rol,
    bool limpiarRol = false,
    FiltroEstadoCuenta? estadoCuenta,
    FiltroEstadoCorreo? estadoCorreo,
  }) {
    final filtros = ref.read(filtrosGestionUsuariosProvider);
    ref.read(filtrosGestionUsuariosProvider.notifier).state = filtros.copyWith(
      rol: rol,
      limpiarRol: limpiarRol,
      estadoCuenta: estadoCuenta,
      estadoCorreo: estadoCorreo,
    );
  }

  void limpiarBusqueda() {
    _debounceBusqueda?.cancel();
    final filtros = ref.read(filtrosGestionUsuariosProvider);
    ref.read(filtrosGestionUsuariosProvider.notifier).state =
        filtros.copyWith(busqueda: '');
  }

  void limpiarFiltros() {
    _debounceBusqueda?.cancel();
    ref.read(filtrosGestionUsuariosProvider.notifier).state =
        const FiltrosGestionUsuarios();
  }

  Future<void> actualizarPermisos(
    UsuarioApp usuario, {
    String? nombre,
    String? correo,
    String? rut,
    RolUsuario? rol,
    bool? cuentaActiva,
  }) async {
    await ref.read(usuariosAdminRepositoryProvider).actualizarPermisos(
          usuarioId: usuario.id,
          nombre: nombre,
          correo: correo,
          rut: rut,
          rol: rol,
          cuentaActiva: cuentaActiva,
        );
    recargar();
  }

  Future<void> reenviarCorreoCuenta(UsuarioApp usuario) {
    final usuariosRepository = ref.read(usuariosAdminRepositoryProvider);
    return usuario.debeCambiarContrasena
        ? usuariosRepository.reenviarAcceso(usuario.id)
        : usuariosRepository.reenviarVerificacion(usuario.id);
  }

  Future<void> crearUsuario({
    required String nombre,
    required String correo,
    required String rut,
    required RolUsuario rol,
  }) async {
    await ref.read(usuariosAdminRepositoryProvider).crearUsuario(
          nombre: nombre,
          correo: correo,
          rut: rut,
          rol: rol,
        );
    recargar();
  }

  Future<void> eliminarUsuario(UsuarioApp usuario) async {
    await ref.read(usuariosAdminRepositoryProvider).eliminarUsuario(usuario.id);
    recargar();
  }
}

final gestionUsuariosVmProvider =
    AsyncNotifierProvider.autoDispose<GestionUsuariosVm, List<UsuarioApp>>(
  GestionUsuariosVm.new,
);
