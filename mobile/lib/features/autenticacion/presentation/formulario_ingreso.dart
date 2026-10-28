import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/autenticacion/presentation/validaciones_ingreso.dart';
import 'package:ubbike/shared/widgets/estilos_formulario_autenticacion.dart';

class FormularioIngreso extends StatelessWidget {
  const FormularioIngreso({
    super.key,
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
          decoration: decoracionCampoAutenticacion(
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
          validator: validarCorreoIngreso,
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: contrasenaController,
          decoration: decoracionCampoAutenticacion(
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
          validator: validarContrasenaIngreso,
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
          style: estiloBotonAutenticacion(),
          child:
              cargando ? indicadorBotonAutenticacion() : const Text('Ingresar'),
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
