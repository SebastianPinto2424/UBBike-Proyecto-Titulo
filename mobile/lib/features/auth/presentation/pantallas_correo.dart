import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ubbike/features/auth/application/autenticacion_vm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/widgets/contenedor_responsivo.dart';
import 'package:ubbike/shared/widgets/marca_ubbike.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/features/auth/presentation/pantalla_login.dart';
import 'package:ubbike/features/auth/presentation/widgets/estilos_formulario_auth.dart';

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
          mensaje = _mensajeEnlaceAuth(error.mensaje);
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

    return _PantallaEstadoCorreo(
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
        context.mostrarError(_mensajeEnlaceAuth(error.mensaje));
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
        context.mostrarError(_mensajeEnlaceAuth(error.mensaje));
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
      return _PantallaEstadoCorreo(
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

String _mensajeEnlaceAuth(String mensaje) {
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

class _PantallaEstadoCorreo extends StatelessWidget {
  const _PantallaEstadoCorreo({
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
