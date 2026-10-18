import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:ubbike/core/configuracion/configuracion_api.dart';
import 'package:ubbike/core/servicios/cliente_http.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';

class ClienteApi {
  const ClienteApi({
    this.obtenerToken,
    this.obtenerRefreshToken,
    this.obtenerUsuarioId,
    this.alActualizarTokens,
    this.alExpirarSesion,
    this.httpClient,
    this.timeout = const Duration(seconds: 20),
  });

  final String? Function()? obtenerToken;
  final String? Function()? obtenerRefreshToken;
  final String? Function()? obtenerUsuarioId;
  final Future<void> Function(String token, String? refreshToken)?
      alActualizarTokens;
  final Future<void> Function()? alExpirarSesion;
  final http.Client? httpClient;
  final Duration timeout;
  http.Client get _http => httpClient ?? clienteHttp;

  static final Map<String, Future<bool>> _renovaciones = {};

  Uri _uri(String ruta) => Uri.parse('${ConfiguracionApi.baseUrl}$ruta');

  Map<String, String> _headers() {
    final token = obtenerToken?.call();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static const _reintentosLectura = 2;
  static const _esperaReintento = Duration(milliseconds: 600);

  bool _esFalloTransitorio(Object error) {
    if (error is TimeoutException || error is http.ClientException) {
      return true;
    }
    final tipo = error.runtimeType.toString();
    return tipo == 'SocketException' || tipo == 'HandshakeException';
  }

  Future<http.Response> _leerConReintento(
    Future<http.Response> Function() solicitud,
  ) async {
    for (var intento = 0;; intento++) {
      try {
        return await _respuesta(solicitud);
      } catch (error) {
        if (intento >= _reintentosLectura || !_esFalloTransitorio(error)) {
          rethrow;
        }
        await Future<void>.delayed(_esperaReintento * (intento + 1));
      }
    }
  }

  Future<Map<String, dynamic>> get(String ruta) async {
    return _procesarRespuesta(await _leerConReintento(
        () => _http.get(_uri(ruta), headers: _headers())));
  }

  Future<String> getTexto(String ruta) async {
    final respuesta = await _leerConReintento(
        () => _http.get(_uri(ruta), headers: _headers()));
    if (respuesta.statusCode >= 400) _procesarRespuesta(respuesta);
    return respuesta.body;
  }

  Future<Uint8List> getBytes(String ruta) async {
    final respuesta = await _leerConReintento(
        () => _http.get(_uri(ruta), headers: _headers()));
    if (respuesta.statusCode >= 400) _procesarRespuesta(respuesta);
    return respuesta.bodyBytes;
  }

  Future<Map<String, dynamic>> post(
    String ruta, {
    Map<String, dynamic>? body,
  }) async {
    return _ejecutar(
      () => _http.post(
        _uri(ruta),
        headers: _headers(),
        body: jsonEncode(body ?? {}),
      ),
    );
  }

  Future<Map<String, dynamic>> patch(
    String ruta, {
    Map<String, dynamic>? body,
  }) async {
    return _ejecutar(
      () => _http.patch(
        _uri(ruta),
        headers: _headers(),
        body: jsonEncode(body ?? {}),
      ),
    );
  }

  Future<Map<String, dynamic>> delete(
    String ruta, {
    Map<String, dynamic>? body,
  }) async {
    return _ejecutar(
      () => _http.delete(
        _uri(ruta),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> _ejecutar(
    Future<http.Response> Function() solicitud,
  ) async {
    return _procesarRespuesta(await _respuesta(solicitud));
  }

  Future<http.Response> _respuesta(
    Future<http.Response> Function() solicitud,
  ) async {
    final tokenEnviado = obtenerToken?.call();
    final usuarioEnviado = obtenerUsuarioId?.call();
    var respuesta = await solicitud().timeout(timeout);

    if (respuesta.statusCode == 401) {
      if (obtenerUsuarioId?.call() != usuarioEnviado) return respuesta;

      if (obtenerToken?.call() != tokenEnviado) {
        return solicitud().timeout(timeout);
      }
      final refreshToken = obtenerRefreshToken?.call();
      final usuarioId = obtenerUsuarioId?.call();

      if (refreshToken != null &&
          usuarioId != null &&
          alActualizarTokens != null) {
        final clave = '$usuarioId:$refreshToken';
        final renovacion = _renovaciones.putIfAbsent(
          clave,
          () => _intentarRefresh(refreshToken, usuarioId),
        );
        final bool reintentado;
        try {
          reintentado = await renovacion;
        } finally {
          if (identical(_renovaciones[clave], renovacion)) {
            unawaited(_renovaciones.remove(clave)!);
          }
        }
        if (reintentado) {
          respuesta = await solicitud().timeout(timeout);
        }
      }
    }

    return respuesta;
  }

  Future<bool> _intentarRefresh(
    String refreshToken,
    String usuarioId,
  ) async {
    final respuesta = await _http
        .post(
          Uri.parse('${ConfiguracionApi.baseUrl}/autenticacion/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(
              {'usuarioId': usuarioId, 'refreshToken': refreshToken}),
        )
        .timeout(timeout);

    if (respuesta.statusCode == 200) {
      final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
      final nuevoToken = datos['token'] as String;
      final nuevoRefreshToken = datos['refreshToken'] as String?;
      if (obtenerRefreshToken?.call() != refreshToken) return false;
      await alActualizarTokens!(nuevoToken, nuevoRefreshToken);
      return true;
    }
    if (respuesta.statusCode == 401 || respuesta.statusCode == 403) {
      if (obtenerRefreshToken?.call() == refreshToken) {
        await alExpirarSesion?.call();
      }
    } else {
      _procesarRespuesta(respuesta);
      throw const ExcepcionApi(
          'No se pudo renovar la sesión. Intenta nuevamente.');
    }
    return false;
  }

  Map<String, dynamic> _procesarRespuesta(http.Response respuesta) {
    Map<String, dynamic> contenido;
    try {
      contenido = respuesta.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(respuesta.body) as Map<String, dynamic>;
    } on FormatException {
      contenido = <String, dynamic>{};
    }

    if (respuesta.statusCode >= 400) {
      final details = contenido['details'] as List?;
      final primerDetalle = details != null && details.isNotEmpty
          ? details.first.toString()
          : null;
      final mensaje = primerDetalle ?? contenido['message']?.toString();
      throw ExcepcionApi(
        _mensajeApiAmigable(mensaje) ?? 'Error ${respuesta.statusCode}',
        statusCode: respuesta.statusCode,
      );
    }

    return contenido;
  }

  String? _mensajeApiAmigable(String? mensaje) {
    if (mensaje == null || mensaje.trim().isEmpty) {
      return null;
    }

    final texto = mensaje.trim();
    final textoLower = texto.toLowerCase();
    final campo = _campoDesdeMensajeJoi(texto);

    if (textoLower.contains('refresh token') ||
        textoLower.contains('token de autenticacion') ||
        textoLower.contains('token de autenticación')) {
      return 'Tu sesión venció. Inicia sesión nuevamente.';
    }
    if (textoLower.contains('token') && textoLower.contains('contrase')) {
      return 'El enlace para cambiar tu contraseña no es válido o expiró. Solicita uno nuevo.';
    }
    if (textoLower.contains('token') && textoLower.contains('registro')) {
      return 'El enlace de registro no es válido o expiró. Solicita uno nuevo para continuar.';
    }
    if (textoLower.contains('token') && textoLower.contains('verificaci')) {
      return 'El enlace de verificación no es válido o expiró. Solicita uno nuevo para continuar.';
    }
    if (textoLower.contains('"token"')) {
      return 'El enlace no es válido o expiró. Solicita uno nuevo para continuar.';
    }

    if (textoLower.contains('must be a valid email')) {
      return campo == null
          ? 'Ingresa un correo válido. Ej: usuario@ubiobio.cl'
          : 'Ingresa un $campo válido. Ej: usuario@ubiobio.cl';
    }
    if (textoLower.contains('is not allowed to be empty') ||
        textoLower.contains('is required')) {
      return campo == null ? 'Completa este campo.' : 'Completa $campo.';
    }
    if (textoLower.contains('length must be at least')) {
      return campo == null
          ? 'Ingresa mas caracteres.'
          : '$campo debe tener mas caracteres.';
    }
    if (textoLower.contains('length must be less than or equal to')) {
      return campo == null
          ? 'El texto ingresado es demasiado largo.'
          : '$campo es demasiado largo.';
    }
    if (textoLower.contains('fails to match the required pattern') ||
        textoLower.contains('must be one of') ||
        textoLower.contains('contains an invalid value')) {
      return campo == null ? 'Revisa el valor ingresado.' : 'Revisa $campo.';
    }
    if (texto.contains('"')) {
      return 'Revisa los datos ingresados.';
    }

    return texto;
  }

  String? _campoDesdeMensajeJoi(String mensaje) {
    final coincidencia = RegExp(r'"([^"]+)"').firstMatch(mensaje);
    if (coincidencia == null) {
      return null;
    }

    final campo = coincidencia.group(1);
    return switch (campo) {
      'correo' => 'correo',
      'contrasena' => 'contrasena',
      'nombre' => 'nombre',
      'rut' => 'RUT',
      'descripcion' => 'descripcion',
      'bicicletaDescripcion' => 'descripción de bicicleta',
      'comentario' => 'comentario',
      'motivo' => 'motivo',
      'mensaje' => 'mensaje',
      _ => 'campo',
    };
  }
}
