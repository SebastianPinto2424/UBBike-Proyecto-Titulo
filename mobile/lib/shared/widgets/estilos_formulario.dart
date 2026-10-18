import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';

const _alturaCampoFormularioBicicleta = 56.0;
const _paddingCampoFormularioBicicleta =
    EdgeInsets.symmetric(horizontal: 14, vertical: 14);

InputDecoration decoracionCampoFormularioBicicleta({
  required String labelText,
  String? errorText,
  String? helperText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    errorText: errorText,
    helperText: helperText,
    helperMaxLines: 2,
    helperStyle: const TextStyle(color: ColoresUbb.textoSecundario),
    errorMaxLines: 3,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: _paddingCampoFormularioBicicleta,
    constraints:
        const BoxConstraints(minHeight: _alturaCampoFormularioBicicleta),
  );
}
