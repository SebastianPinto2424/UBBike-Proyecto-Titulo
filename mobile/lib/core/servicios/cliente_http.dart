import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'package:ubbike/core/configuracion/configuracion_api.dart';

http.Client clienteHttp = http.Client();

class _HttpOverridesConCertificado extends HttpOverrides {
  _HttpOverridesConCertificado(this._contexto);

  final SecurityContext _contexto;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(_contexto);
}

Future<void> inicializarClienteHttp() async {
  if (!ConfiguracionApi.baseUrl.startsWith('https')) {
    return;
  }

  try {
    final contexto = SecurityContext(withTrustedRoots: true);
    final certificado = await rootBundle.load('assets/certs/ubbike.crt');
    contexto.setTrustedCertificatesBytes(certificado.buffer.asUint8List());
    clienteHttp = IOClient(HttpClient(context: contexto));
    HttpOverrides.global = _HttpOverridesConCertificado(contexto);
  } catch (error) {
    if (kDebugMode) {
      debugPrint('No se pudo cargar el certificado pinned: $error');
    }
  }
}
