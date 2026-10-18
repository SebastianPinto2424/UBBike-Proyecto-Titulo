import 'package:flutter/material.dart';

import 'package:ubbike/features/auth/presentation/validaciones_ingreso.dart';
import 'package:ubbike/shared/widgets/estilos_formulario_auth.dart';

class SheetRecuperacion extends StatefulWidget {
  const SheetRecuperacion({
    super.key,
    required this.correoInicial,
    required this.onEnviar,
  });

  final String correoInicial;
  final Future<void> Function(String correo) onEnviar;

  @override
  State<SheetRecuperacion> createState() => _SheetRecuperacionState();
}

class _SheetRecuperacionState extends State<SheetRecuperacion> {
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
                  validator: validarCorreoAuthFrontend,
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
