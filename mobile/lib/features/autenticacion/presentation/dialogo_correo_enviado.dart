import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/widgets/estilos_formulario_autenticacion.dart';

class DialogoCorreoEnviado extends StatelessWidget {
  const DialogoCorreoEnviado({
    super.key,
    required this.correo,
    required this.mensaje,
  });

  final String correo;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final estiloTexto = tema.textTheme.bodyMedium?.copyWith(
      color: ColoresUbb.textoSecundario,
      height: 1.35,
    );

    return AlertDialog(
      scrollable: true,
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
            style: tema.textTheme.titleLarge?.copyWith(
              color: ColoresUbb.textoPrincipal,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Enviamos un enlace a '),
                TextSpan(
                  text: correo,
                  style: const TextStyle(
                    color: ColoresUbb.textoPrincipal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
            style: estiloTexto,
          ),
          const SizedBox(height: 8),
          Text(mensaje, textAlign: TextAlign.center, style: estiloTexto),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: estiloBotonAutenticacion(),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Volver al ingreso'),
            ),
          ),
        ],
      ),
    );
  }
}
