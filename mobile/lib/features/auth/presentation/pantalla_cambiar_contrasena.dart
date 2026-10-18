import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/auth/application/autenticacion_vm.dart';
import 'package:ubbike/features/auth/presentation/pantalla_login.dart';
import 'package:ubbike/features/auth/presentation/estado_correo_widgets.dart';
import 'package:ubbike/shared/widgets/contenedor_responsivo.dart';
import 'package:ubbike/shared/widgets/estilos_formulario_auth.dart';
import 'package:ubbike/shared/widgets/marca_ubbike.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';

class PantallaCambiarContrasena extends ConsumerStatefulWidget {
  const PantallaCambiarContrasena({
    super.key,
    required this.token,
    this.esActivacion = false,
  });

  final String token;

  final bool esActivacion;

  @override
  ConsumerState<PantallaCambiarContrasena> createState() =>
      _PantallaCambiarContrasenaState();
}

class _PantallaCambiarContrasenaState
    extends ConsumerState<PantallaCambiarContrasena> {
  final formKey = GlobalKey<FormState>();
  final contrasenaController = TextEditingController();
  final confirmarContrasenaController = TextEditingController();
  bool cargando = false;
  bool mostrarContrasena = false;
  bool mostrarConfirmacion = false;
  bool cambioCompletado = false;
  @override
  void dispose() {
    contrasenaController.dispose();
    confirmarContrasenaController.dispose();
    super.dispose();
  }

  Future<void> _cambiar() async {
    if (formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => cargando = true);

    try {
      final mensaje = await ref.read(autenticacionVmProvider).cambiarContrasena(
            token: widget.token,
            contrasena: contrasenaController.text,
          );

      if (mounted) {
        await ref.read(sesionProvider.notifier).cerrar();
      }

      if (mounted) {
        if (kIsWeb) {
          setState(() {
            cambioCompletado = true;
          });
        } else {
          context.mostrarExito(mensaje);
          _mostrarLoginContrasenaActualizada();
        }
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
    if (cambioCompletado) {
      return PantallaEstadoCorreo(
        titulo:
            widget.esActivacion ? 'Cuenta activada' : 'Contraseña actualizada',
        mensaje: widget.esActivacion
            ? 'Tu cuenta quedó activa. Abre la app UBBike e inicia sesión con tu correo institucional y la contraseña que acabas de crear.'
            : 'Tu contraseña fue actualizada correctamente. Vuelve a la app e inicia sesión con tu nueva contraseña.',
        cargando: false,
        icono: Icons.check_circle_outline,
        color: ColoresUbb.exito,
        textoAccion: 'Iniciar sesión',
        onAccion: _mostrarLoginContrasenaActualizada,
      );
    }

    if (kIsWeb) {
      return _construirVistaWeb(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.esActivacion ? 'Activa tu cuenta' : 'Cambiar contraseña',
        ),
      ),
      body: ContenedorResponsivo(
        anchoMaximo: 520,
        child: ListView(
          children: [
            const MarcaUbbike(compacta: true),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.esActivacion
                      ? 'Crea tu contraseña'
                      : 'Nueva contraseña',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: contrasenaController,
                        obscureText: !mostrarContrasena,
                        decoration: decoracionCampoAuth(
                          labelText: 'Contraseña',
                          icono: Icons.lock_outline,
                          suffixIcon: IconButton(
                            tooltip: mostrarContrasena
                                ? 'Ocultar contraseña'
                                : 'Mostrar contraseña',
                            onPressed: () {
                              setState(
                                () => mostrarContrasena = !mostrarContrasena,
                              );
                            },
                            icon: Icon(
                              mostrarContrasena
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: _validarContrasenaAuth,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: confirmarContrasenaController,
                        obscureText: !mostrarConfirmacion,
                        decoration: decoracionCampoAuth(
                          labelText: 'Confirmar contraseña',
                          icono: Icons.lock_outline,
                          suffixIcon: IconButton(
                            tooltip: mostrarConfirmacion
                                ? 'Ocultar contraseña'
                                : 'Mostrar contraseña',
                            onPressed: () {
                              setState(
                                () =>
                                    mostrarConfirmacion = !mostrarConfirmacion,
                              );
                            },
                            icon: Icon(
                              mostrarConfirmacion
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) {
                          final texto = value ?? '';
                          if (texto.isEmpty) {
                            return 'Confirma tu nueva contraseña.';
                          }
                          if (texto != contrasenaController.text) {
                            return 'Las contraseñas no coinciden.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 26),
                      ElevatedButton(
                        style: estiloBotonAuth(),
                        onPressed: cargando ? null : _cambiar,
                        child: cargando
                            ? indicadorBotonAuth()
                            : Text(
                                widget.esActivacion
                                    ? 'Crear contraseña'
                                    : 'Guardar cambio',
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirVistaWeb(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final esPantallaEstrecha = constraints.maxWidth < 600;

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: esPantallaEstrecha ? 16 : 24,
                      vertical: 24,
                    ),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: EdgeInsets.all(esPantallaEstrecha ? 22 : 28),
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const MarcaUbbike(compacta: true),
                              const SizedBox(height: 22),
                              Icon(
                                widget.esActivacion
                                    ? Icons.badge_outlined
                                    : Icons.lock_reset_outlined,
                                color: ColoresUbb.azulApp,
                                size: 44,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.esActivacion
                                    ? 'Activa tu cuenta UBBike'
                                    : 'Nueva contraseña',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.esActivacion
                                    ? 'Tu cuenta fue creada por un administrador. Crea la contraseña con la que iniciarás sesión en la app.'
                                    : 'Crea una contraseña segura para volver a ingresar.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: ColoresUbb.textoSecundario,
                                      height: 1.35,
                                    ),
                              ),
                              const SizedBox(height: 22),
                              _campoContrasena(
                                controller: contrasenaController,
                                labelText: 'Contraseña',
                                mostrarTexto: mostrarContrasena,
                                onAlternarVisibilidad: () {
                                  setState(
                                    () =>
                                        mostrarContrasena = !mostrarContrasena,
                                  );
                                },
                                textInputAction: TextInputAction.next,
                                validator: _validarContrasenaAuth,
                              ),
                              const SizedBox(height: 16),
                              _campoContrasena(
                                controller: confirmarContrasenaController,
                                labelText: 'Confirmar contraseña',
                                mostrarTexto: mostrarConfirmacion,
                                onAlternarVisibilidad: () {
                                  setState(
                                    () => mostrarConfirmacion =
                                        !mostrarConfirmacion,
                                  );
                                },
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _cambiar(),
                                validator: _validarConfirmacionContrasena,
                              ),
                              const SizedBox(height: 22),
                              ElevatedButton(
                                style: estiloBotonAuth(),
                                onPressed: cargando ? null : _cambiar,
                                child: cargando
                                    ? indicadorBotonAuth()
                                    : Text(
                                        widget.esActivacion
                                            ? 'Crear contraseña y activar'
                                            : 'Guardar contraseña',
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  TextFormField _campoContrasena({
    required TextEditingController controller,
    required String labelText,
    required bool mostrarTexto,
    required VoidCallback onAlternarVisibilidad,
    required TextInputAction textInputAction,
    required String? Function(String?) validator,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !mostrarTexto,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.newPassword],
      decoration: decoracionCampoAuth(
        labelText: labelText,
        icono: Icons.lock_outline,
        suffixIcon: IconButton(
          tooltip: mostrarTexto ? 'Ocultar contraseña' : 'Mostrar contraseña',
          onPressed: onAlternarVisibilidad,
          icon: Icon(
            mostrarTexto
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
    );
  }

  String? _validarConfirmacionContrasena(String? value) {
    final texto = value ?? '';
    if (texto.isEmpty) {
      return 'Confirma tu nueva contraseña.';
    }
    if (texto != contrasenaController.text) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  void _mostrarLoginContrasenaActualizada() {
    unawaited(Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const PantallaLogin(
          mensajeInicial:
              'Contraseña actualizada. Ingresa con tu nueva contraseña.',
        ),
      ),
      (_) => false,
    ));
  }
}

String? _validarContrasenaAuth(String? value) {
  if (value == null || value.isEmpty) {
    return 'La contraseña es obligatoria.';
  }

  final segura = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{12,}$',
  );
  if (!segura.hasMatch(value)) {
    return 'Mínimo 12 caracteres con mayúscula, minúscula, número y símbolo.';
  }
  return null;
}
