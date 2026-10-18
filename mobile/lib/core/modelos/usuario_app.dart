import 'package:ubbike/core/modelos/rol_usuario.dart';

class UsuarioApp {
  const UsuarioApp({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.correoVerificado,
    required this.registroParcial,
    required this.cuentaActiva,
    this.debeCambiarContrasena = false,
    this.rut,
    this.eliminadoEn,
  });

  final String id;
  final String nombre;
  final String correo;
  final String? rut;
  final RolUsuario rol;
  final bool correoVerificado;
  final bool registroParcial;
  final bool cuentaActiva;
  final bool debeCambiarContrasena;
  final DateTime? eliminadoEn;

  factory UsuarioApp.fromJson(Map<String, dynamic> json) {
    return UsuarioApp(
      id: json['id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      correo: json['correo'] as String? ?? '',
      rut: json['rut'] as String?,
      rol: EtiquetaRolUsuario.desdeApi(json['rol'] as String? ?? 'ESTUDIANTE'),
      correoVerificado: json['correoVerificado'] as bool? ?? false,
      registroParcial: json['registroParcial'] as bool? ?? false,
      cuentaActiva: json['cuentaActiva'] as bool? ?? true,
      debeCambiarContrasena: json['debeCambiarContrasena'] as bool? ?? false,
      eliminadoEn: json['eliminadoEn'] == null
          ? null
          : DateTime.parse(json['eliminadoEn'] as String),
    );
  }

  factory UsuarioApp.desdeJson(Map<String, dynamic> json) =>
      UsuarioApp.fromJson(json);
}
