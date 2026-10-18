import 'dart:convert';

import 'package:ubbike/core/servicios/almacen_seguro.dart';

const _storageKeyBorrador = 'ubbike_borrador_incidencia';

const _storage = AlmacenSeguro();

class BorradorIncidencia {
  const BorradorIncidencia({
    required this.bicicleteroId,
    required this.bicicletaId,
    required this.tipo,
    required this.descripcion,
    required this.fotos,
  });

  final String? bicicleteroId;
  final String? bicicletaId;
  final String tipo;
  final String descripcion;
  final List<String> fotos;

  Map<String, dynamic> aJson() => {
        'bicicleteroId': bicicleteroId,
        'bicicletaId': bicicletaId,
        'tipo': tipo,
        'descripcion': descripcion,
        'fotos': fotos,
      };

  factory BorradorIncidencia.desdeJson(Map<String, dynamic> json) {
    return BorradorIncidencia(
      bicicleteroId: json['bicicleteroId'] as String?,
      bicicletaId: json['bicicletaId'] as String?,
      tipo: json['tipo'] as String? ?? 'OTRO',
      descripcion: json['descripcion'] as String? ?? '',
      fotos: (json['fotos'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

Future<void> guardarBorradorIncidencia(BorradorIncidencia borrador) async {
  try {
    await _storage.write(
      key: _storageKeyBorrador,
      value: jsonEncode(borrador.aJson()),
    );
  } catch (_) {}
}

Future<bool> existeBorradorIncidencia() async {
  try {
    return await _storage.read(key: _storageKeyBorrador) != null;
  } catch (_) {
    return false;
  }
}

Future<BorradorIncidencia?> tomarBorradorIncidencia() async {
  try {
    final valor = await _storage.read(key: _storageKeyBorrador);
    if (valor == null) {
      return null;
    }
    await _storage.delete(key: _storageKeyBorrador);
    return BorradorIncidencia.desdeJson(
      jsonDecode(valor) as Map<String, dynamic>,
    );
  } catch (_) {
    return null;
  }
}

Future<void> borrarBorradorIncidencia() async {
  try {
    await _storage.delete(key: _storageKeyBorrador);
  } catch (_) {}
}
