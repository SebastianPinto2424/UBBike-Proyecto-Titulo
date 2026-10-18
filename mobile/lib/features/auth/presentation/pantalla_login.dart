import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/configuracion/rutas_app.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/auth/application/autenticacion_vm.dart';
import 'package:ubbike/features/auth/presentation/formulario_ingreso.dart';
import 'package:ubbike/features/auth/presentation/pantalla_registro.dart';
import 'package:ubbike/features/auth/presentation/sheet_recuperacion_contrasena.dart';
import 'package:ubbike/shared/widgets/marca_ubbike.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';

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
                                  child: FormularioIngreso(
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
      if (mounted && ModalRoute.of(context)?.settings.name != rutaRaiz) {
        unawaited(
          Navigator.of(context).pushNamedAndRemoveUntil(rutaRaiz, (_) => false),
        );
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

  void _mostrarRecuperacion(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SheetRecuperacion(
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
