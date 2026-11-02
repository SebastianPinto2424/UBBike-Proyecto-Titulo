import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/autenticacion/application/autenticacion_vm.dart';
import 'package:ubbike/features/autenticacion/presentation/formulario_ingreso.dart';
import 'package:ubbike/features/autenticacion/presentation/pantalla_registro.dart';
import 'package:ubbike/features/autenticacion/presentation/hoja_recuperacion_contrasena.dart';
import 'package:ubbike/shared/widgets/marca_ubbike.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/features/autenticacion/presentation/dialogo_confirmar_correo.dart';

class PantallaInicioSesion extends ConsumerStatefulWidget {
  const PantallaInicioSesion({
    super.key,
    this.mensajeInicial,
  });

  final String? mensajeInicial;

  @override
  ConsumerState<PantallaInicioSesion> createState() =>
      _PantallaInicioSesionState();
}

class _PantallaInicioSesionState extends ConsumerState<PantallaInicioSesion> {
  final formKeyIngreso = GlobalKey<FormState>();
  final correoController = TextEditingController();
  final contrasenaController = TextEditingController();
  bool cargando = false;
  bool mostrarContrasena = false;

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

    _iniciarSesionAsincrona();
  }

  Future<void> _iniciarSesionAsincrona() async {
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
        if (error.codigo == 'CORREO_NO_VERIFICADO') {
          _mostrarCorreoPendiente(correo);
        } else {
          context.mostrarError(error.mensaje);
        }
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError(mensajeSinConexion);
      }
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  void _mostrarCorreoPendiente(String correo) {
    showDialog<void>(
      context: context,
      builder: (_) => DialogoConfirmarCorreo(
        correo: correo,
        onReenviar: () =>
            ref.read(autenticacionVmProvider).reenviarVerificacion(correo),
      ),
    );
  }

  void _mostrarRecuperacion(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => HojaRecuperacion(
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
        context.mostrarError(mensajeSinConexion);
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
