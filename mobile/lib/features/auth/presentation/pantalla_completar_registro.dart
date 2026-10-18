import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/auth/application/autenticacion_vm.dart';
import 'package:ubbike/features/auth/presentation/pantalla_login.dart';
import 'package:ubbike/features/auth/presentation/estado_correo_widgets.dart';
import 'package:ubbike/shared/widgets/contenedor_responsivo.dart';
import 'package:ubbike/shared/widgets/estilos_formulario_auth.dart';
import 'package:ubbike/shared/widgets/marca_ubbike.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';

class PantallaCompletarRegistro extends ConsumerStatefulWidget {
  const PantallaCompletarRegistro({super.key, required this.token});

  final String token;

  @override
  ConsumerState<PantallaCompletarRegistro> createState() =>
      _PantallaCompletarRegistroState();
}

class _PantallaCompletarRegistroState
    extends ConsumerState<PantallaCompletarRegistro> {
  final nombreController = TextEditingController();
  final contrasenaController = TextEditingController();
  bool cargando = false;
  bool mostrarContrasena = false;

  @override
  void dispose() {
    nombreController.dispose();
    contrasenaController.dispose();
    super.dispose();
  }

  Future<void> _completar() async {
    final nombre = nombreController.text.trim();
    final segura = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{12,}$',
    );

    if (nombre.length < 2) {
      context.mostrarError('Ingresa tu nombre completo');
      return;
    }

    if (!segura.hasMatch(contrasenaController.text)) {
      context.mostrarError(
        'Mínimo 12 caracteres con mayúscula, minúscula, número y símbolo',
      );
      return;
    }

    setState(() => cargando = true);

    try {
      final mensaje = await ref.read(autenticacionVmProvider).completarRegistro(
            token: widget.token,
            nombre: nombre,
            contrasena: contrasenaController.text,
          );

      if (mounted) {
        context.mostrarExito(mensaje);
        unawaited(Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PantallaLogin()),
          (_) => false,
        ));
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(mensajeEnlaceAuth(error.mensaje));
      }
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completar registro')),
      body: ContenedorResponsivo(
        anchoMaximo: 560,
        child: ListView(
          children: [
            const MarcaUbbike(compacta: true),
            const SizedBox(height: 20),
            Text(
              'Activa tu cuenta',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Completa tus datos para iniciar sesión y generar códigos QR.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ColoresUbb.textoSecundario,
                  ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: nombreController,
              decoration: decoracionCampoAuth(
                labelText: 'Nombre completo',
                icono: Icons.person_outline,
              ),
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: contrasenaController,
              obscureText: !mostrarContrasena,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.newPassword],
              decoration: decoracionCampoAuth(
                labelText: 'Contraseña',
                icono: Icons.lock_outline,
                suffixIcon: IconButton(
                  tooltip: mostrarContrasena
                      ? 'Ocultar contraseña'
                      : 'Mostrar contraseña',
                  onPressed: () {
                    setState(() => mostrarContrasena = !mostrarContrasena);
                  },
                  icon: Icon(
                    mostrarContrasena
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 26),
            ElevatedButton.icon(
              style: estiloBotonAuth(),
              onPressed: cargando ? null : _completar,
              icon: cargando
                  ? indicadorBotonAuth()
                  : const Icon(Icons.check_circle_outline),
              label: Text(cargando ? 'Activando...' : 'Completar registro'),
            ),
          ],
        ),
      ),
    );
  }
}
