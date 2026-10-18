import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/auth/application/autenticacion_vm.dart';
import 'package:ubbike/features/auth/presentation/pantalla_login.dart';
import 'package:ubbike/features/auth/presentation/estado_correo_widgets.dart';

class PantallaVerificarCorreo extends ConsumerStatefulWidget {
  const PantallaVerificarCorreo({super.key, required this.token});

  final String token;

  @override
  ConsumerState<PantallaVerificarCorreo> createState() =>
      _PantallaVerificarCorreoState();
}

class _PantallaVerificarCorreoState
    extends ConsumerState<PantallaVerificarCorreo> {
  String mensaje = 'Verificando correo...';
  String? correoVerificado;
  bool cargando = true;
  bool correcto = false;

  @override
  void initState() {
    super.initState();
    _verificar();
  }

  Future<void> _verificar() async {
    try {
      final respuesta =
          await ref.read(autenticacionVmProvider).verificarCorreo(widget.token);
      if (mounted) {
        setState(() {
          mensaje =
              'Tu cuenta fue activada correctamente. Vuelve a la app e inicia sesión.';
          correoVerificado = respuesta.correo;
          correcto = true;
          cargando = false;
        });
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        setState(() {
          mensaje = mensajeEnlaceAuth(error.mensaje);
          cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          mensaje = 'No se pudo conectar con el backend';
          cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hayError = !cargando && !correcto;

    return PantallaEstadoCorreo(
      titulo: correcto
          ? 'Cuenta activada'
          : hayError
              ? 'No se pudo verificar'
              : 'Verificación de correo',
      mensaje: mensaje,
      cargando: cargando,
      icono: correcto
          ? Icons.check_circle_outline
          : hayError
              ? Icons.error_outline
              : Icons.mark_email_read_outlined,
      color: correcto
          ? ColoresUbb.exito
          : hayError
              ? ColoresUbb.rojoInstitucional
              : ColoresUbb.azulApp,
      textoAccion: correcto ? 'Iniciar sesión' : 'Volver al inicio de sesión',
      onAccion: correcto
          ? () {
              _mostrarLoginVerificado();
            }
          : null,
    );
  }

  Future<void> _mostrarLoginVerificado() async {
    final correo = correoVerificado?.trim();

    await ref.read(sesionProvider.notifier).cerrar();
    if (!mounted) {
      return;
    }

    unawaited(Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => PantallaLogin(
          correoInicial: correo != null && correo.isNotEmpty ? correo : null,
          mensajeInicial:
              'Cuenta activada. Ingresa tu contraseña para iniciar sesión.',
        ),
      ),
      (_) => false,
    ));
  }
}
