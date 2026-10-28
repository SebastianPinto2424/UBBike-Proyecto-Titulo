import 'package:ubbike/shared/utilidades/identidad.dart';
import 'package:ubbike/shared/utilidades/opciones_bicicleta.dart';

String? validarNombreGestionManual(
  String? valor, {
  bool requerido = false,
}) {
  final nombre = valor?.trim() ?? '';

  if (nombre.isEmpty) {
    return requerido ? 'Ingresa el nombre de la persona.' : null;
  }
  if (nombre.length < 3) {
    return 'Debe tener al menos 3 caracteres.';
  }
  if (nombre.length > 120) {
    return 'Máximo 120 caracteres.';
  }
  return null;
}

String? validarCorreoGestionManual(
  String? valor,
  String rutActual, {
  bool requiereCorreo = false,
}) {
  final correo = valor?.trim() ?? '';
  final rut = rutActual.trim();

  if (requiereCorreo && correo.isEmpty) {
    return 'Ingresa correo para crear el registro parcial.';
  }
  if (correo.isEmpty && rut.isEmpty) {
    return 'Ingresa correo o RUT.';
  }
  if (correo.isEmpty) {
    return null;
  }
  if (correo.length > 160) {
    return 'Máximo 160 caracteres.';
  }

  final correoValido = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  if (!correoValido.hasMatch(correo)) {
    return 'Ingresa un correo válido. Ej: usuario@ubiobio.cl';
  }
  final institucional = correo.toLowerCase().endsWith('@ubiobio.cl') ||
      correo.toLowerCase().endsWith('@alumnos.ubiobio.cl');
  if (requiereCorreo && !institucional) {
    return 'Usa un correo @ubiobio.cl o @alumnos.ubiobio.cl.';
  }
  return null;
}

String? validarRutGestionManual(
  String? valor, {
  bool requerido = false,
}) {
  final rut = valor?.trim() ?? '';
  if (requerido && rut.isEmpty) {
    return 'Ingresa RUT para crear el registro parcial.';
  }
  if (rut.isEmpty) {
    return null;
  }
  if (!rut.contains('-')) {
    return 'El RUT debe incluir el guion (xx.xxx.xxx-x).';
  }
  if (!rutValido(rut)) {
    return 'RUT inválido. Revisa el número y el dígito verificador.';
  }
  return null;
}

String? validarCampoRequeridoConFormato(
  String? valor, {
  required bool requerido,
  required String mensajeRequerido,
  required String? Function(String?) validarFormato,
}) {
  final texto = valor?.trim() ?? '';
  if (requerido && texto.isEmpty) {
    return mensajeRequerido;
  }
  if (!requerido && texto.isEmpty) {
    return null;
  }
  return validarFormato(valor);
}

String? validarAroGestionManual(
  String? valor, {
  required bool requerido,
}) {
  final texto = valor?.trim() ?? '';
  if (requerido && texto.isEmpty) {
    return 'Ingresa el aro.';
  }
  if (!requerido && texto.isEmpty) {
    return null;
  }
  if (normalizarAroBicicleta(texto) == null) {
    return 'Ingresa un aro válido.';
  }
  return null;
}

String? validarDescripcionBicicletaManual(
  String? valor,
  bool requerida,
) {
  final texto = valor?.trim() ?? '';
  if (!requerida && texto.isEmpty) {
    return null;
  }
  return validarDescripcionBicicleta(texto);
}

String? validarCampoOpcionalGestionManual(String? valor, int maximo) {
  final texto = valor?.trim() ?? '';
  if (texto.length > maximo) {
    return 'Máximo $maximo caracteres.';
  }
  return null;
}
