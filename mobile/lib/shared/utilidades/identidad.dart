import 'package:flutter/services.dart';

class FormateadorRut extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.toUpperCase();
    final tieneGuion = raw.contains('-');
    final partes = raw.split('-');

    final cuerpoDigitos = partes.first.replaceAll(RegExp(r'[^0-9]'), '');
    final cuerpo = cuerpoDigitos.length > 8
        ? cuerpoDigitos.substring(0, 8)
        : cuerpoDigitos;

    var dv = '';
    if (tieneGuion && partes.length > 1) {
      final dvLimpio =
          partes.sublist(1).join().replaceAll(RegExp(r'[^0-9K]'), '');
      dv = dvLimpio.isEmpty ? '' : dvLimpio.substring(0, 1);
    }

    final cuerpoFmt =
        cuerpo.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    final texto = tieneGuion ? '$cuerpoFmt-$dv' : cuerpoFmt;

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

bool rutValido(String valor) {
  final limpio = valor.trim().toUpperCase();
  if (!RegExp(r'^[\d.]+-[\dK]$').hasMatch(limpio)) {
    return false;
  }

  final partes = limpio.split('-');
  final cuerpo = partes.first.replaceAll('.', '');
  final dv = partes[1];

  if (!RegExp(r'^\d{7,8}$').hasMatch(cuerpo)) {
    return false;
  }

  var suma = 0;
  var multiplicador = 2;
  for (var i = cuerpo.length - 1; i >= 0; i--) {
    suma += int.parse(cuerpo[i]) * multiplicador;
    multiplicador = multiplicador == 7 ? 2 : multiplicador + 1;
  }

  final esperado = 11 - (suma % 11);
  final dvEsperado = switch (esperado) {
    11 => '0',
    10 => 'K',
    _ => esperado.toString(),
  };

  return dv == dvEsperado;
}

final _palabraNombre = RegExp(
  r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+(?:['-][A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*$",
);

bool nombreCompletoValido(String valor) {
  final partes =
      valor.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.length != 4) {
    return false;
  }
  return partes.every(_palabraNombre.hasMatch);
}

String nombreCorto(String nombreCompleto) {
  final partes = nombreCompleto
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();

  if (partes.isEmpty) {
    return nombreCompleto.trim();
  }
  if (partes.length >= 4) {
    return '${partes[0]} ${partes[2]}';
  }
  if (partes.length >= 2) {
    return '${partes[0]} ${partes[1]}';
  }
  return partes[0];
}
