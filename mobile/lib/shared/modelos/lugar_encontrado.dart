import 'package:ubbike/shared/modelos/punto_geografico.dart';

class LugarEncontrado {
  const LugarEncontrado({
    required this.titulo,
    required this.detalle,
    required this.punto,
  });

  final String titulo;
  final String detalle;
  final PuntoGeografico punto;

  static LugarEncontrado? desdeJson(Map<String, dynamic> json) {
    final punto = PuntoGeografico.desdeTexto(
      json['lat']?.toString() ?? '',
      json['lon']?.toString() ?? '',
    );
    if (punto == null) return null;

    final completo = (json['display_name']?.toString() ?? '').trim();
    if (completo.isEmpty) return null;

    final partes = completo.split(',').map((p) => p.trim()).toList();
    return LugarEncontrado(
      titulo: partes.first,
      detalle: partes.length > 1 ? partes.sublist(1).join(', ') : '',
      punto: punto,
    );
  }
}
