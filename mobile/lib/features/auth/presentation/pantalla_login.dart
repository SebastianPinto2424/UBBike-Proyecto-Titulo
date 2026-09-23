import 'package:flutter/material.dart';
import 'package:ubbike/features/auth/application/autenticacion_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/auth/presentation/pantalla_registro.dart';
import 'package:ubbike/shared/widgets/marca_ubbike.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/features/auth/presentation/widgets/estilos_formulario_auth.dart';

class PantallaLogin extends ConsumerStatefulWidget {
  const PantallaLogin({
    super.key,
    this.correoInicial,
    this.mensajeInicial,
  });

  final String? correoInicial;
  final String? mensajeInicial;

  @override
  ConsumerState<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends ConsumerState<PantallaLogin> {
  final formKeyIngreso = GlobalKey<FormState>();
  final correoController = TextEditingController();
  final contrasenaController = TextEditingController();
  bool cargando = false;
  bool mostrarContrasena = false;

  @override
  void initState() {
    super.initState();
    final correo = widget.correoInicial?.trim();
    if (correo != null && correo.isNotEmpty) {
      correoController.text = correo;
    }
  }

  @override
  void didUpdateWidget(covariant PantallaLogin oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nuevoCorreo = widget.correoInicial?.trim();
    if (nuevoCorreo != null &&
        nuevoCorreo.isNotEmpty &&
        nuevoCorreo != oldWidget.correoInicial) {
      correoController.text = nuevoCorreo;
    }
  }

  @override
  void dispose() {
    correoController.dispose();
    contrasenaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresUbb.azulNoche,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final tecladoAbierto = MediaQuery.viewInsetsOf(context).bottom > 0;
          final alturaCabecera = (tecladoAbierto ? 92.0 : 200.0) +
              MediaQuery.paddingOf(context).top;
          final altoFormulario = (constraints.maxHeight - alturaCabecera)
              .clamp(0.0, double.infinity);

          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: tecladoAbierto
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  _CabeceraIngreso(tecladoAbierto: tecladoAbierto),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: altoFormulario,
                    ),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: ColoresUbb.fondo,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                18,
                                20,
                                24,
                              ),
                              child: AutofillGroup(
                                child: Form(
                                  key: formKeyIngreso,
                                  child: _FormularioIngreso(
                                    correoController: correoController,
                                    contrasenaController: contrasenaController,
                                    cargando: cargando,
                                    mostrarContrasena: mostrarContrasena,
                                    mensajeInicial: widget.mensajeInicial,
                                    onAlternarContrasena: () {
                                      setState(
                                        () => mostrarContrasena =
                                            !mostrarContrasena,
                                      );
                                    },
                                    onIngresar: _iniciarSesion,
                                    onRegistro: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const PantallaRegistro(),
                                        ),
                                      );
                                    },
                                    onRecuperar: () =>
                                        _mostrarRecuperacion(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _iniciarSesion() {
    if (cargando) {
      return;
    }
    if (formKeyIngreso.currentState?.validate() != true) {
      return;
    }

    _iniciarSesionAsync();
  }

  Future<void> _iniciarSesionAsync() async {
    final correo = correoController.text.trim().toLowerCase();
    final contrasena = contrasenaController.text;

    if (correo.isEmpty || contrasena.isEmpty) {
      context.mostrarError('Ingresa correo y contraseña');
      return;
    }

    setState(() => cargando = true);

    try {
      final resultado = await ref.read(autenticacionVmProvider).iniciarSesion(
            correo: correo,
            contrasena: contrasena,
          );

      await ref.read(sesionProvider.notifier).iniciar(
            token: resultado.token,
            usuario: resultado.usuario,
            refreshToken: resultado.refreshToken,
          );
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError('No se pudo conectar con el backend');
      }
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  void _mostrarRecuperacion(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SheetRecuperacion(
        correoInicial: correoController.text.trim(),
        onEnviar: _enviarRecuperacion,
      ),
    );
  }

  Future<void> _enviarRecuperacion(String correo) async {
    try {
      final mensaje = await ref
          .read(autenticacionVmProvider)
          .solicitarCambioContrasena(correo);
      if (mounted) {
        context.mostrarExito(mensaje);
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError('No se pudo conectar con el backend');
      }
    }
  }
}

class _SheetRecuperacion extends StatefulWidget {
  const _SheetRecuperacion({
    required this.correoInicial,
    required this.onEnviar,
  });

  final String correoInicial;
  final Future<void> Function(String correo) onEnviar;

  @override
  State<_SheetRecuperacion> createState() => _SheetRecuperacionState();
}

class _SheetRecuperacionState extends State<_SheetRecuperacion> {
  final formKeyRecuperacion = GlobalKey<FormState>();
  late final TextEditingController correoRecuperacionController;

  @override
  void initState() {
    super.initState();
    correoRecuperacionController =
        TextEditingController(text: widget.correoInicial);
  }

  @override
  void dispose() {
    correoRecuperacionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: AutofillGroup(
          child: Form(
            key: formKeyRecuperacion,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Recuperar contraseña',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enviaremos un enlace seguro al correo registrado.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: correoRecuperacionController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  autofillHints: const [AutofillHints.email],
                  decoration: decoracionCampoAuth(
                    labelText: 'Correo registrado',
                    icono: Icons.mail_outline,
                  ),
                  validator: _validarCorreoAuthFrontend,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: estiloBotonAuth(),
                  onPressed: () {
                    if (formKeyRecuperacion.currentState?.validate() != true) {
                      return;
                    }
                    final correo = correoRecuperacionController.text.trim();
                    Navigator.pop(context);
                    widget.onEnviar(correo);
                  },
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Enviar correo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _validarCorreoAuthFrontend(String? valor) {
  final correo = valor?.trim() ?? '';
  if (correo.isEmpty) {
    return 'Ingresa el correo.';
  }
  if (correo.length > 160) {
    return 'Maximo 160 caracteres.';
  }

  final correoValido = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  if (!correoValido.hasMatch(correo)) {
    return 'Ingresa un correo valido. Ej: estudiante@alumnos.ubiobio.cl';
  }
  return null;
}

String? _validarContrasenaLoginFrontend(String? valor) {
  if (valor == null || valor.isEmpty) {
    return 'Ingresa la contrasena.';
  }
  return null;
}

class _CabeceraIngreso extends StatelessWidget {
  const _CabeceraIngreso({required this.tecladoAbierto});

  final bool tecladoAbierto;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: tecladoAbierto ? 92 : 200,
        child: Center(
          child: MarcaUbbike(
            compacta: true,
            sobreAzul: true,
            alto: tecladoAbierto ? 36 : 62,
          ),
        ),
      ),
    );
  }
}

class _FormularioIngreso extends StatelessWidget {
  const _FormularioIngreso({
    required this.correoController,
    required this.contrasenaController,
    required this.cargando,
    required this.mostrarContrasena,
    required this.mensajeInicial,
    required this.onAlternarContrasena,
    required this.onIngresar,
    required this.onRegistro,
    required this.onRecuperar,
  });

  final TextEditingController correoController;
  final TextEditingController contrasenaController;
  final bool cargando;
  final bool mostrarContrasena;
  final String? mensajeInicial;
  final VoidCallback onAlternarContrasena;
  final VoidCallback onIngresar;
  final VoidCallback onRegistro;
  final VoidCallback onRecuperar;

  @override
  Widget build(BuildContext context) {
    final estiloEnlace = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: ColoresUbb.textoPrincipal,
          fontWeight: FontWeight.w500,
        );
    final estiloEnlaceDestacado = estiloEnlace?.copyWith(
      fontWeight: FontWeight.w900,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Iniciar Sesión',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: ColoresUbb.textoPrincipal,
                fontWeight: FontWeight.w900,
              ),
        ),
        if (mensajeInicial?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 14),
          _AvisoIngreso(mensaje: mensajeInicial!.trim()),
        ],
        const SizedBox(height: 22),
        TextFormField(
          controller: correoController,
          decoration: decoracionCampoAuth(
            labelText: 'Correo electrónico',
            icono: Icons.mail_outline,
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          autofillHints: const [
            AutofillHints.username,
            AutofillHints.email,
          ],
          validator: _validarCorreoAuthFrontend,
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: contrasenaController,
          decoration: decoracionCampoAuth(
            labelText: 'Contraseña',
            icono: Icons.lock_outline,
            suffixIcon: IconButton(
              tooltip: mostrarContrasena
                  ? 'Ocultar contraseña'
                  : 'Mostrar contraseña',
              onPressed: onAlternarContrasena,
              icon: Icon(
                mostrarContrasena
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          obscureText: !mostrarContrasena,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onIngresar(),
          validator: _validarContrasenaLoginFrontend,
        ),
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onRecuperar,
            style: TextButton.styleFrom(
              foregroundColor: ColoresUbb.textoPrincipal,
              shape: const StadiumBorder(),
            ),
            child: RichText(
              textAlign: TextAlign.right,
              text: TextSpan(
                style: estiloEnlace,
                children: [
                  const TextSpan(text: '¿Has olvidado tu contraseña? '),
                  TextSpan(text: 'Recuperar', style: estiloEnlaceDestacado),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: cargando ? null : onIngresar,
          style: estiloBotonAuth(),
          child: cargando ? indicadorBotonAuth() : const Text('Ingresar'),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: onRegistro,
          style: TextButton.styleFrom(
            foregroundColor: ColoresUbb.textoPrincipal,
            shape: const StadiumBorder(),
          ),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: estiloEnlace,
              children: [
                const TextSpan(text: '¿Aún no tienes cuenta? '),
                TextSpan(text: 'Registrarse', style: estiloEnlaceDestacado),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AvisoIngreso extends StatelessWidget {
  const _AvisoIngreso({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresUbb.exito.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresUbb.exito.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: ColoresUbb.exito,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mensaje,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColoresUbb.textoPrincipal,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
