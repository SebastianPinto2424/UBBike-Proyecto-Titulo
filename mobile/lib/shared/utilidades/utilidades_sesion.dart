import 'package:flutter/widgets.dart';

import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/utilidades/leer_provider.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/shared/utilidades/identidad.dart';

String saludoActual() {
  final hora = DateTime.now().hour;
  if (hora < 12) {
    return 'Buenos días';
  }
  if (hora < 20) {
    return 'Buenas tardes';
  }
  return 'Buenas noches';
}

String textoNoVacio(String? valor, String respaldo) {
  final texto = valor?.trim();
  if (texto == null || texto.isEmpty) {
    return respaldo;
  }
  return texto;
}

String nombreSesion(BuildContext context, String respaldo) {
  final sesion = leerProvider(context, sesionProvider).value;
  final nombre = sesion is SesionActiva ? sesion.usuario.nombre : null;
  return nombreCorto(textoNoVacio(nombre, respaldo));
}

RolUsuario rolSesionActual(BuildContext context) {
  final sesion = leerProvider(context, sesionProvider).value;
  return sesion is SesionActiva ? sesion.usuario.rol : RolUsuario.estudiante;
}
