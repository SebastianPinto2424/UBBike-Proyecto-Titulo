import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/features/auth/data/autenticacion_api.dart';
import 'package:ubbike/features/auth/data/autenticacion_repository.dart';
import 'package:ubbike/shared/modelos/rol_usuario.dart';
import 'package:ubbike/shared/modelos/usuario_app.dart';

sealed class SesionState {
  const SesionState();
}

class SesionCargando extends SesionState {
  const SesionCargando();
}

class SesionVacia extends SesionState {
  const SesionVacia();
}

class SesionActiva extends SesionState {
  const SesionActiva({
    required this.usuario,
    required this.token,
    this.refreshToken,
  });

  final UsuarioApp usuario;
  final String token;
  final String? refreshToken;
}

const _storageKeyToken = 'ubbike_jwt';
const _storageKeyRefreshToken = 'ubbike_refresh';
const _storageKeyUsuarioId = 'ubbike_usuario_id';
const _storageKeyUsuarioNombre = 'ubbike_usuario_nombre';
const _storageKeyUsuarioCorreo = 'ubbike_usuario_correo';
const _storageKeyUsuarioRol = 'ubbike_usuario_rol';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

class SesionNotifier extends AsyncNotifier<SesionState> {
  int _epoca = 0;
  Future<void> _escrituras = Future.value();
  Future<void> _persistir(Future<void> Function() accion) {
    final resultado = _escrituras.then((_) => accion());
    _escrituras = resultado.catchError((Object _) {});
    return resultado;
  }

  @override
  Future<SesionState> build() => _restaurarSesion();

  Future<SesionState> _restaurarSesion() async {
    final epoca = ++_epoca;
    await _escrituras;
    var token = await _storage.read(key: _storageKeyToken);
    var refresh = await _storage.read(key: _storageKeyRefreshToken);
    final id = await _storage.read(key: _storageKeyUsuarioId);
    if (token == null) return const SesionVacia();
    try {
      final api = ClienteApi(
        httpClient: ref.read(sesionHttpProvider),
        obtenerToken: () => epoca == _epoca ? token : null,
        obtenerRefreshToken: () => epoca == _epoca ? refresh : null,
        obtenerUsuarioId: () => epoca == _epoca ? id : null,
        alActualizarTokens: (t, r) async {
          if (epoca != _epoca) return;
          token = t;
          refresh = r;
          await _persistir(() async {
            await _storage.write(key: _storageKeyToken, value: t);
            await _storage.write(key: _storageKeyRefreshToken, value: r);
          });
        },
      );
      final usuario =
          await AutenticacionRepository(AutenticacionApi(cliente: api))
              .obtenerPerfil();
      if (epoca != _epoca) return state.valueOrNull ?? const SesionVacia();
      return SesionActiva(
          usuario: usuario, token: token!, refreshToken: refresh);
    } on ExcepcionApi catch (error) {
      if (epoca != _epoca) return state.valueOrNull ?? const SesionVacia();
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _persistir(_limpiarStorage);
        return const SesionVacia();
      }
      rethrow;
    }
  }

  Future<void> iniciar(
      {required String token,
      required UsuarioApp usuario,
      String? refreshToken}) async {
    final epoca = ++_epoca;
    await _persistir(() async {
      await _storage.write(key: _storageKeyToken, value: token);
      await _storage.write(key: _storageKeyUsuarioId, value: usuario.id);
      await _storage.write(
          key: _storageKeyUsuarioNombre, value: usuario.nombre);
      await _storage.write(
          key: _storageKeyUsuarioCorreo, value: usuario.correo);
      await _storage.write(
          key: _storageKeyUsuarioRol, value: usuario.rol.valorApi);
      if (refreshToken == null) {
        await _storage.delete(key: _storageKeyRefreshToken);
      } else {
        await _storage.write(key: _storageKeyRefreshToken, value: refreshToken);
      }
    });
    if (epoca == _epoca) {
      state = AsyncData(SesionActiva(
          usuario: usuario, token: token, refreshToken: refreshToken));
    }
  }

  Future<void> actualizarToken(
      String nuevoToken, String? nuevoRefreshToken) async {
    final actual = state.valueOrNull;
    if (actual is! SesionActiva) return;
    final refresh = nuevoRefreshToken ?? actual.refreshToken;

    state = AsyncData(SesionActiva(
        usuario: actual.usuario, token: nuevoToken, refreshToken: refresh));
    await _persistir(() async {
      await _storage.write(key: _storageKeyToken, value: nuevoToken);
      await _storage.write(key: _storageKeyRefreshToken, value: refresh);
    });
  }

  Future<void> refrescarPerfil() async {
    final actual = state.valueOrNull;
    if (actual is! SesionActiva) return;
    final epoca = _epoca;
    final api = ClienteApi(
      httpClient: ref.read(sesionHttpProvider),
      obtenerToken: () =>
          switch (state.valueOrNull) { SesionActiva s => s.token, _ => null },
      obtenerRefreshToken: () => switch (state.valueOrNull) {
        SesionActiva s => s.refreshToken,
        _ => null
      },
      obtenerUsuarioId: () => switch (state.valueOrNull) {
        SesionActiva s => s.usuario.id,
        _ => null
      },
      alActualizarTokens: actualizarToken,
      alExpirarSesion: olvidar,
    );
    final usuario =
        await AutenticacionRepository(AutenticacionApi(cliente: api))
            .obtenerPerfil();
    final vigente = state.valueOrNull;
    if (epoca != _epoca ||
        vigente is! SesionActiva ||
        vigente.usuario.id != usuario.id) {
      return;
    }
    state = AsyncData(SesionActiva(
        usuario: usuario,
        token: vigente.token,
        refreshToken: vigente.refreshToken));
  }

  Future<void> cerrar() async {
    final actual = state.valueOrNull;
    final httpClient = ref.read(sesionHttpProvider);
    await olvidar();
    if (actual is! SesionActiva) return;
    try {
      await AutenticacionRepository(AutenticacionApi(
          cliente: ClienteApi(
        httpClient: httpClient,
        obtenerToken: () => actual.token,
        timeout: const Duration(seconds: 5),
      ))).cerrarSesion(refreshToken: actual.refreshToken);
    } catch (_) {}
  }

  Future<void> olvidar() async {
    _epoca++;
    state = const AsyncData(SesionVacia());
    await _persistir(_limpiarStorage);
  }

  Future<void> _limpiarStorage() async {
    for (final clave in [
      _storageKeyToken,
      _storageKeyRefreshToken,
      _storageKeyUsuarioId,
      _storageKeyUsuarioNombre,
      _storageKeyUsuarioCorreo,
      _storageKeyUsuarioRol
    ]) {
      await _storage.delete(key: clave);
    }
  }
}

final sesionHttpProvider = Provider<http.Client?>((ref) => null);

final sesionProvider = AsyncNotifierProvider<SesionNotifier, SesionState>(
  SesionNotifier.new,
);
