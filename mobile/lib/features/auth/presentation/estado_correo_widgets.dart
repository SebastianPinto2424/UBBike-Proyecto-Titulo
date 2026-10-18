import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ubbike/features/auth/presentation/pantalla_login.dart';
import 'package:ubbike/shared/widgets/contenedor_responsivo.dart';
import 'package:ubbike/shared/widgets/estilos_formulario_auth.dart';
import 'package:ubbike/shared/widgets/marca_ubbike.dart';

String mensajeEnlaceAuth(String mensaje) {
  final texto = mensaje.trim();
  final textoLower = texto.toLowerCase();

  if (textoLower.contains('token') || textoLower.contains('enlace')) {
    if (textoLower.contains('contrase')) {
      return 'El enlace para cambiar tu contraseña no es válido o expiró. Solicita uno nuevo desde Recuperar contraseña.';
    }
    if (textoLower.contains('registro')) {
      return 'El enlace de registro no es válido o expiró. Solicita apoyo al guardia para recibir uno nuevo.';
    }
    if (textoLower.contains('verificaci')) {
      return 'El enlace de verificación no es válido o expiró. Solicita uno nuevo para continuar.';
    }
    return 'El enlace no es válido o expiró. Solicita uno nuevo para continuar.';
  }

  return texto;
}

class PantallaEstadoCorreo extends StatelessWidget {
  const PantallaEstadoCorreo({
    super.key,
    required this.titulo,
    required this.mensaje,
    required this.cargando,
    required this.icono,
    required this.color,
    this.textoAccion,
    this.onAccion,
  });

  final String titulo;
  final String mensaje;
  final bool cargando;
  final IconData icono;
  final Color color;
  final String? textoAccion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ContenedorResponsivo(
        anchoMaximo: 520,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MarcaUbbike(compacta: true),
                  const SizedBox(height: 22),
                  Icon(icono, color: color, size: 48),
                  const SizedBox(height: 14),
                  Text(
                    titulo,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(mensaje, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  if (cargando)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          style: estiloBotonAuth(),
                          onPressed: onAccion ??
                              () {
                                unawaited(
                                    Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const PantallaLogin(),
                                  ),
                                  (_) => false,
                                ));
                              },
                          icon: const Icon(Icons.login),
                          label: Text(textoAccion ?? 'Iniciar sesión'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
