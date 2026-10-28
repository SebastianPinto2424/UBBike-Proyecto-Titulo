import 'dart:convert';

import 'package:ubbike/core/servicios/almacen_seguro.dart';

const _claveBorrador = 'ubbike_borrador_bicicleta';

const _almacen = AlmacenSeguro();

class BorradorBicicleta {
  const BorradorBicicleta({
    required this.descripcion,
    required this.marca,
    required this.modelo,
    required this.color,
    required this.aro,
    required this.numeroSerie,
    required this.activar,
  });

  final String descripcion;
  final String marca;
  final String modelo;
  final String color;
  final String? aro;
  final String numeroSerie;
  final bool activar;

  Map<String, dynamic> aJson() => {
        'descripcion': descripcion,
        'marca': marca,
        'modelo': modelo,
        'color': color,
        'aro': aro,
        'numeroSerie': numeroSerie,
        'activar': activar,
      };

  factory BorradorBicicleta.desdeJson(Map<String, dynamic> json) {
    return BorradorBicicleta(
      descripcion: json['descripcion'] as String? ?? '',
      marca: json['marca'] as String? ?? '',
      modelo: json['modelo'] as String? ?? '',
      color: json['color'] as String? ?? '',
      aro: json['aro'] as String?,
      numeroSerie: json['numeroSerie'] as String? ?? '',
      activar: json['activar'] as bool? ?? true,
    );
  }
}

Future<void> guardarBorradorBicicleta(BorradorBicicleta borrador) async {
  await _almacen.escribir(
    clave: _claveBorrador,
    valor: jsonEncode(borrador.aJson()),
  );
}

Future<BorradorBicicleta?> leerBorradorBicicleta() async {
  final valor = await _almacen.leer(clave: _claveBorrador);
  if (valor == null) {
    return null;
  }

  try {
    return BorradorBicicleta.desdeJson(
      jsonDecode(valor) as Map<String, dynamic>,
    );
  } catch (_) {
    return null;
  }
}

Future<void> borrarBorradorBicicleta() async {
  await _almacen.borrar(clave: _claveBorrador);
}
