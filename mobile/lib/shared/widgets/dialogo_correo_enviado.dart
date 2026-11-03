import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/widgets/estilos_formulario_autenticacion.dart';

const _cortePermitido = '\u200B';

class DialogoCorreoEnviado extends StatelessWidget {
  const DialogoCorreoEnviado({
    super.key,
    required this.proposito,
    this.correo,
    this.nota,
    this.textoBoton = 'Entendido',
  });

  final String proposito;
  final String? correo;
  final String? nota;
  final String textoBoton;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final estiloTexto = tema.textTheme.bodyMedium?.copyWith(
      color: ColoresUbb.textoSecundario,
      height: 1.35,
    );
    final correo = this.correo;
    final nota = this.nota;

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
            'Revisa tu correo',
            textAlign: TextAlign.center,
            style: tema.textTheme.titleLarge?.copyWith(
              color: ColoresUbb.textoPrincipal,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: correo == null
                  ? [TextSpan(text: 'Te enviamos un enlace para $proposito.')]
                  : [
                      TextSpan(text: 'Enviamos un enlace para $proposito a '),
                      TextSpan(
                        text: correo.replaceFirst('@', '@$_cortePermitido'),
                        semanticsLabel: correo,
                        style: const TextStyle(
                          color: ColoresUbb.textoPrincipal,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
            ),
            key: const Key('texto-envio'),
            textAlign: TextAlign.center,
            style: estiloTexto,
          ),
          if (nota != null) ...[
            const SizedBox(height: 12),
            Text(nota, textAlign: TextAlign.center, style: estiloTexto),
          ],
          const SizedBox(height: 12),
          Text(
            '¿No lo ves? Revisa la carpeta de spam.',
            textAlign: TextAlign.center,
            style: estiloTexto,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: estiloBotonAutenticacion(),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(textoBoton),
            ),
          ),
        ],
      ),
    );
  }
}
