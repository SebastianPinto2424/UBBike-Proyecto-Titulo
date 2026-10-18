import 'package:flutter/material.dart';
import 'package:ubbike/features/auth/application/autenticacion_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/utils/identidad.dart';
import 'package:ubbike/shared/widgets/contenedor_responsivo.dart';
import 'package:ubbike/shared/widgets/marca_ubbike.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/estilos_formulario_auth.dart';

class PantallaRegistro extends ConsumerStatefulWidget {
  const PantallaRegistro({super.key});

  @override
  ConsumerState<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends ConsumerState<PantallaRegistro> {
  final formKey = GlobalKey<FormState>();
  final nombreController = TextEditingController();
  final rutController = TextEditingController();
  final correoController = TextEditingController();
  final contrasenaController = TextEditingController();
  final nombreFocusNode = FocusNode();
  final rutFocusNode = FocusNode();
  final correoFocusNode = FocusNode();
  final contrasenaFocusNode = FocusNode();
  bool cargando = false;
  bool mostrarContrasena = false;

  @override
  void initState() {
    super.initState();
    nombreFocusNode.addListener(_actualizarAyudaCampo);
    rutFocusNode.addListener(_actualizarAyudaCampo);
    correoFocusNode.addListener(_actualizarAyudaCampo);
    contrasenaFocusNode.addListener(_actualizarAyudaCampo);
  }

  @override
  void dispose() {
    nombreFocusNode.removeListener(_actualizarAyudaCampo);
    rutFocusNode.removeListener(_actualizarAyudaCampo);
    correoFocusNode.removeListener(_actualizarAyudaCampo);
    contrasenaFocusNode.removeListener(_actualizarAyudaCampo);
    nombreFocusNode.dispose();
    rutFocusNode.dispose();
    correoFocusNode.dispose();
    contrasenaFocusNode.dispose();
    nombreController.dispose();
    rutController.dispose();
    correoController.dispose();
    contrasenaController.dispose();
    super.dispose();
  }

  void _actualizarAyudaCampo() {
    if (mounted) {
      setState(() {});
    }
  }

  String? _ayudaSiActivo(FocusNode focusNode, String texto) {
    return focusNode.hasFocus ? texto : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro')),
      body: ContenedorResponsivo(
        anchoMaximo: 560,
        child: ListView(
          children: [
            const MarcaUbbike(compacta: true),
            const SizedBox(height: 22),
            Text(
              'Crear cuenta',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: ColoresUbb.textoPrincipal,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Se enviará un correo de activación. La cuenta no queda habilitada hasta confirmar el enlace.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ColoresUbb.textoSecundario,
                  ),
            ),
            const SizedBox(height: 18),
            AutofillGroup(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: nombreController,
                      focusNode: nombreFocusNode,
                      decoration: decoracionCampoAuth(
                        labelText: 'Nombre completo',
                        icono: Icons.person_outline,
                        helperText: _ayudaSiActivo(
                          nombreFocusNode,
                          'Dos nombres y dos apellidos (ej: Nombre Nombre Apellido Apellido)',
                        ),
                      ),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: (value) {
                        return _validarNombreRegistroFrontend(value);
                      },
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: rutController,
                      focusNode: rutFocusNode,
                      decoration: decoracionCampoAuth(
                        labelText: 'RUT',
                        icono: Icons.badge_outlined,
                        helperText: _ayudaSiActivo(
                          rutFocusNode,
                          'Con guion, formato xx.xxx.xxx-x',
                        ),
                      ),
                      keyboardType: TextInputType.text,
                      inputFormatters: [RutInputFormatter()],
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      validator: (value) {
                        return _validarRutRegistroFrontend(value);
                      },
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: correoController,
                      focusNode: correoFocusNode,
                      decoration: decoracionCampoAuth(
                        labelText: 'Correo institucional',
                        icono: Icons.mail_outline,
                        helperText: _ayudaSiActivo(
                          correoFocusNode,
                          'Debe terminar en @ubiobio.cl o @alumnos.ubiobio.cl',
                        ),
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
                      validator: (value) {
                        final correo = value?.trim() ?? '';
                        if (correo.isEmpty) {
                          return 'El correo es obligatorio.';
                        }
                        if (correo.length > 160) {
                          return 'Máximo 160 caracteres.';
                        }
                        final correoValido =
                            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
                        if (!correoValido.hasMatch(correo)) {
                          return 'Ingresa un correo válido. Ej: estudiante@alumnos.ubiobio.cl';
                        }
                        if (!correo.endsWith('@ubiobio.cl') &&
                            !correo.endsWith('@alumnos.ubiobio.cl')) {
                          return 'Debe ser @ubiobio.cl o @alumnos.ubiobio.cl';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: contrasenaController,
                      focusNode: contrasenaFocusNode,
                      decoration: decoracionCampoAuth(
                        labelText: 'Contraseña',
                        icono: Icons.lock_outline,
                        helperText: _ayudaSiActivo(
                          contrasenaFocusNode,
                          'Mínimo 12 caracteres con mayúscula, minúscula, número y símbolo',
                        ),
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
                      obscureText: !mostrarContrasena,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      validator: (value) {
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
                      },
                    ),
                    const SizedBox(height: 26),
                    ElevatedButton(
                      style: estiloBotonAuth(),
                      onPressed: cargando ? null : _registrar,
                      child: cargando
                          ? indicadorBotonAuth()
                          : const Text('Registrar'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registrar() async {
    if (formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => cargando = true);

    try {
      final correo = correoController.text.trim();

      final mensaje = await ref.read(autenticacionVmProvider).registrar(
            nombre: nombreController.text.trim(),
            rut: rutController.text.trim(),
            correo: correo,
            contrasena: contrasenaController.text,
          );

      if (mounted) {
        _mostrarConfirmacion(context, mensaje);
      }
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

  void _mostrarConfirmacion(BuildContext context, String mensaje) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: ColoresUbb.fondo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: ColoresUbb.exito.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: ColoresUbb.exito,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Correo enviado',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: ColoresUbb.textoPrincipal,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ColoresUbb.textoSecundario,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: estiloBotonAuth(),
                  onPressed: () {
                    Navigator.of(context)
                      ..pop()
                      ..pop();
                  },
                  child: const Text('Volver al ingreso'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String? _validarNombreRegistroFrontend(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'El nombre es obligatorio.';
  }
  if (texto.length > 120) {
    return 'Máximo 120 caracteres.';
  }
  if (!nombreCompletoValido(texto)) {
    return 'Ingresa dos nombres y dos apellidos (Nombre Nombre Apellido Apellido).';
  }
  return null;
}

String? _validarRutRegistroFrontend(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'El RUT es obligatorio.';
  }
  if (!texto.contains('-')) {
    return 'El RUT debe incluir el guion (xx.xxx.xxx-x).';
  }
  if (!rutValido(texto)) {
    return 'RUT inválido. Revisa el número y el dígito verificador.';
  }
  return null;
}
