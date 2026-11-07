import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';

InputDecoration decoracionSoloLectura(
  InputDecoration base, {
  String? textoVacio,
}) {
  return base.copyWith(
    hintText: textoVacio,
    hintMaxLines: 1,
    filled: true,
    fillColor: ColoresUbb.fondo,
    floatingLabelBehavior: FloatingLabelBehavior.always,
  );
}

class CampoSoloLectura extends StatelessWidget {
  const CampoSoloLectura({
    super.key,
    required this.decoracion,
    this.valor,
    this.controlador,
    this.textoVacio = 'Sin información',
  }) : assert(valor == null || controlador == null);

  final InputDecoration decoracion;
  final String? valor;
  final TextEditingController? controlador;
  final String textoVacio;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: controlador == null ? ValueKey(valor) : null,
      controller: controlador,
      initialValue: controlador == null ? valor : null,
      readOnly: true,
      canRequestFocus: false,
      enableInteractiveSelection: false,
      minLines: 1,
      maxLines: null,
      decoration: decoracionSoloLectura(decoracion, textoVacio: textoVacio),
    );
  }
}
