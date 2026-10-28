import 'package:flutter/foundation.dart';

class ConfiguracionApi {
  static const _baseUrlDefinida = String.fromEnvironment('API_BASE_URL');
  static const _puertoLocal =
      String.fromEnvironment('API_LOCAL_PORT', defaultValue: '3000');

  static String get baseUrl {
    final base = _baseUrlDefinida.isNotEmpty
        ? _baseUrlDefinida
        : _baseUrlLocalPorPlataforma;

    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  static String get _baseUrlLocalPorPlataforma {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$_puertoLocal';
    }

    return 'http://localhost:$_puertoLocal';
  }
}
