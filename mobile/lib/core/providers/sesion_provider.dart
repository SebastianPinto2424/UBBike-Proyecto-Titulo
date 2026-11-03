import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:ubbike/core/servicios/almacen_seguro.dart';
import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/servicios/sesion_api.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';

sealed class EstadoSesion {
  const EstadoSesion();
}

class SesionCargando extends EstadoSesion {
  const SesionCargando();
}

class SesionVacia extends EstadoSesion {
  const SesionVacia({this.motivo});

  final String? motivo;
}

class SesionActiva extends EstadoSesion {
  const SesionActiva({
    required this.usuario,
    required this.token,
    this.refreshToken,
  });

  final UsuarioApp usuario;
  final String token;
  final String? refreshToken;
}

const mensajeSesionExpirada =
    'Tu sesión terminó. Si iniciaste sesión con esta cuenta en otro '
    'dispositivo, aquí se cerró. Ingresa nuevamente.';

const mensajeSesionEnOtroDispositivo =
    'Iniciaste sesión con esta cuenta en otro dispositivo, por eso se '
    'cerró aquí.';

const mensajeCuentaEliminada =
    'Administración eliminó tu cuenta, por eso se cerró la sesión.';

const mensajeCuentaDesactivada =
    'Administración desactivó tu cuenta, por eso se cerró la sesión.';

const mensajeCuentaActualizada =
    'Administración actualizó tu cuenta. Ingresa nuevamente para continuar.';

const mensajeContrasenaActualizada =
    'Cambiaste tu contraseña. Ingresa con la nueva.';

String mensajeCierreRemoto(String? motivo) => switch (motivo) {
      'CUENTA_ELIMINADA' => mensajeCuentaEliminada,
      'CUENTA_DESACTIVADA' => mensajeCuentaDesactivada,
      'CUENTA_ACTUALIZADA' => mensajeCuentaActualizada,
      'CONTRASENA_ACTUALIZADA' => mensajeContrasenaActualizada,
      _ => mensajeSesionEnOtroDispositivo,
    };

const _claveToken = 'ubbike_jwt';
const _claveRefreshToken = 'ubbike_refresh';
const _claveUsuarioId = 'ubbike_usuario_id';
const _claveUsuarioNombre = 'ubbike_usuario_nombre';
const _claveUsuarioCorreo = 'ubbike_usuario_correo';
const _claveUsuarioRol = 'ubbike_usuario_rol';

const _almacen = AlmacenSeguro();

class SesionNotifier extends AsyncNotifier<EstadoSesion> {
  int _epoca = 0;
  Future<void> _escrituras = Future.value();
  Future<void> _persistir(Future<void> Function() accion) {
    final resultado = _escrituras.then((_) => accion());
    _escrituras = resultado.catchError((Object _) {});
    return resultado;
  }

  @override
  Future<EstadoSesion> build() => _restaurarSesion();

  Future<EstadoSesion> _restaurarSesion() async {
    final epoca = ++_epoca;
    await _escrituras;
    var token = await _almacen.leer(clave: _claveToken);
    var refresh = await _almacen.leer(clave: _claveRefreshToken);
    final id = await _almacen.leer(clave: _claveUsuarioId);
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
            await _almacen.escribir(clave: _claveToken, valor: t);
            await _almacen.escribir(clave: _claveRefreshToken, valor: r);
          });
        },
      );
      final usuario = await SesionApi(cliente: api).obtenerPerfil();
      if (epoca != _epoca) return state.valueOrNull ?? const SesionVacia();
      return SesionActiva(
          usuario: usuario, token: token!, refreshToken: refresh);
    } on ExcepcionApi catch (error) {
      if (epoca != _epoca) return state.valueOrNull ?? const SesionVacia();
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _persistir(_limpiarAlmacen);
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
      await _almacen.escribir(clave: _claveToken, valor: token);
      await _almacen.escribir(clave: _claveUsuarioId, valor: usuario.id);
      await _almacen.escribir(
          clave: _claveUsuarioNombre, valor: usuario.nombre);
      await _almacen.escribir(
          clave: _claveUsuarioCorreo, valor: usuario.correo);
      await _almacen.escribir(
          clave: _claveUsuarioRol, valor: usuario.rol.valorApi);
      if (refreshToken == null) {
        await _almacen.borrar(clave: _claveRefreshToken);
      } else {
        await _almacen.escribir(clave: _claveRefreshToken, valor: refreshToken);
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
      await _almacen.escribir(clave: _claveToken, valor: nuevoToken);
      await _almacen.escribir(clave: _claveRefreshToken, valor: refresh);
    });
  }

  Future<void> renovarSesion() async {
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
      alExpirarSesion: () => olvidar(motivo: mensajeSesionExpirada),
    );
    final usuario = await SesionApi(cliente: api).obtenerPerfil();
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
      await SesionApi(
          cliente: ClienteApi(
        httpClient: httpClient,
        obtenerToken: () => actual.token,
        timeout: const Duration(seconds: 5),
      )).cerrarSesion(refreshToken: actual.refreshToken);
    } catch (_) {}
  }

  Future<void> cerrarPorAvisoDelServidor(String? motivo) =>
      olvidar(motivo: mensajeCierreRemoto(motivo));

  Future<void> olvidar({String? motivo}) async {
    _epoca++;
    state = AsyncData(SesionVacia(motivo: motivo));
    await _persistir(_limpiarAlmacen);
  }

  Future<void> _limpiarAlmacen() async {
    for (final clave in [
      _claveToken,
      _claveRefreshToken,
      _claveUsuarioId,
      _claveUsuarioNombre,
      _claveUsuarioCorreo,
      _claveUsuarioRol
    ]) {
      await _almacen.borrar(clave: clave);
    }
  }
}

final sesionHttpProvider = Provider<http.Client?>((ref) => null);

final sesionProvider = AsyncNotifierProvider<SesionNotifier, EstadoSesion>(
  SesionNotifier.new,
);
