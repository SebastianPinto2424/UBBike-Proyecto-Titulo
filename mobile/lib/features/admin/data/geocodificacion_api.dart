import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:ubbike/core/configuracion/configuracion_mapa.dart';
import 'package:ubbike/core/servicios/cliente_http.dart';
import 'package:ubbike/shared/modelos/lugar_encontrado.dart';

class GeocodificacionApi {
  const GeocodificacionApi({this.cliente});

  final http.Client? cliente;

  http.Client get _http => cliente ?? clienteHttp;

  Future<List<LugarEncontrado>> buscar(
    String consulta, {
    int limite = 6,
    Duration limiteTiempo = const Duration(seconds: 12),
  }) async {
    final texto = consulta.trim();
    if (texto.length < 3) return const [];

    final uri = Uri.parse(ConfiguracionMapa.urlBusqueda).replace(
      queryParameters: {
        'q': texto,
        'format': 'jsonv2',
        'limit': '$limite',
        'addressdetails': '0',
        if (ConfiguracionMapa.paisBusqueda.isNotEmpty)
          'countrycodes': ConfiguracionMapa.paisBusqueda,
      },
    );

    final respuesta = await _http.get(uri, headers: {
      'User-Agent': ConfiguracionMapa.agenteBusqueda,
      'Accept': 'application/json',
    }).timeout(limiteTiempo);

    if (respuesta.statusCode >= 400) {
      throw const FormatException('El buscador de direcciones no respondio');
    }

    final cuerpo = jsonDecode(respuesta.body);
    if (cuerpo is! List) return const [];

    return cuerpo
        .whereType<Map<String, dynamic>>()
        .map(LugarEncontrado.desdeJson)
        .whereType<LugarEncontrado>()
        .toList();
  }
}
