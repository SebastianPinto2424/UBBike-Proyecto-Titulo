String? validarCorreoAuthFrontend(String? valor) {
  final correo = valor?.trim() ?? '';
  if (correo.isEmpty) {
    return 'Ingresa el correo.';
  }
  if (correo.length > 160) {
    return 'Máximo 160 caracteres.';
  }

  final correoValido = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  if (!correoValido.hasMatch(correo)) {
    return 'Ingresa un correo válido. Ej: estudiante@alumnos.ubiobio.cl';
  }
  return null;
}

String? validarContrasenaLoginFrontend(String? valor) {
  if (valor == null || valor.isEmpty) {
    return 'Ingresa la contraseña.';
  }
  return null;
}
