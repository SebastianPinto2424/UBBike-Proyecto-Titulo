import 'package:flutter/material.dart';
import 'package:ubbike/features/auth/application/autenticacion_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';

class PantallaCambioObligatorio extends ConsumerStatefulWidget {
  const PantallaCambioObligatorio({super.key});

  @override
  ConsumerState<PantallaCambioObligatorio> createState() =>
      _PantallaCambioObligatorioState();
}

class _PantallaCambioObligatorioState
    extends ConsumerState<PantallaCambioObligatorio> {
  final formKey = GlobalKey<FormState>();
  final actualController = TextEditingController();
  final nuevaController = TextEditingController();
  final confirmarController = TextEditingController();
  bool verActual = false;
  bool verNueva = false;
  bool guardando = false;

  @override
  void dispose() {
    actualController.dispose();
    nuevaController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => guardando = true);
    try {
      await ref.read(autenticacionVmProvider).cambiarContrasenaSesion(
            contrasenaActual: actualController.text,
            contrasenaNueva: nuevaController.text,
          );

      if (mounted) {
        context.mostrarExito(
          'Contraseña actualizada. Inicia sesión con tu nueva contraseña.',
        );
      }

      await ref.read(sesionProvider.notifier).cerrar();
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
        setState(() => guardando = false);
      }
    }
  }

  Future<void> _cerrarSesion() async {
    await ref.read(sesionProvider.notifier).cerrar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Cambia tu contraseña'),
        actions: [
          TextButton(
            onPressed: guardando ? null : _cerrarSesion,
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: ColoresUbb.superficieAzulSuave,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.lock_reset_outlined,
                            color: ColoresUbb.azulApp,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Define tu nueva contraseña',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tu cuenta requiere actualizar la contraseña. Por seguridad, '
                          'define una nueva antes de continuar.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: ColoresUbb.textoSecundario,
                                  ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: actualController,
                          obscureText: !verActual,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: 'Contraseña actual',
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => verActual = !verActual),
                              icon: Icon(
                                verActual
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: (valor) => (valor == null || valor.isEmpty)
                              ? 'Ingresa tu contraseña actual.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nuevaController,
                          obscureText: !verNueva,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: 'Nueva contraseña',
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => verNueva = !verNueva),
                              icon: Icon(
                                verNueva
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: _validarNueva,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmarController,
                          obscureText: !verNueva,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _guardar(),
                          decoration: const InputDecoration(
                            labelText: 'Confirmar nueva contraseña',
                          ),
                          validator: (valor) => valor != nuevaController.text
                              ? 'Las contraseñas no coinciden.'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: guardando ? null : _guardar,
                          icon: guardando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            guardando ? 'Guardando' : 'Guardar y continuar',
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
  }
}

String? _validarNueva(String? valor) {
  final texto = valor ?? '';
  if (texto.isEmpty) {
    return 'Ingresa una contraseña.';
  }
  if (texto.length < 12) {
    return 'Mínimo 12 caracteres.';
  }
  if (texto.length > 72) {
    return 'Máximo 72 caracteres.';
  }
  final segura =
      RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).+$');
  if (!segura.hasMatch(texto)) {
    return 'Incluye mayúscula, minúscula, número y símbolo.';
  }
  return null;
}
