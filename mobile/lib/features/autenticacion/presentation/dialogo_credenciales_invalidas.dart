import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/widgets/estilos_formulario_autenticacion.dart';

class DialogoCredencialesInvalidas extends StatelessWidget {
  const DialogoCredencialesInvalidas({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AlertDialog(
      scrollable: true,
      backgroundColor: ColoresUbb.fondo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ColoresUbb.rojoInstitucional.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              color: ColoresUbb.rojoInstitucional,
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No pudimos iniciar sesión',
            textAlign: TextAlign.center,
            style: tema.textTheme.titleLarge?.copyWith(
              color: ColoresUbb.textoPrincipal,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'El correo o la contraseña ingresados no son válidos. '
            'Revisa tus datos e inténtalo nuevamente. Si aún no tienes una '
            'cuenta, regístrate para comenzar a usar UBBike.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyMedium?.copyWith(
              color: ColoresUbb.textoSecundario,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('revisar-credenciales'),
              style: estiloBotonAutenticacion(),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Revisar datos'),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const Key('crear-cuenta-desde-credenciales'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Crear cuenta'),
          ),
        ],
      ),
    );
  }
}
