import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/features/perfil/presentation/pantalla_principal_perfil.dart';
import 'package:ubbike/shared/widgets/dialogo_correo_enviado.dart';

import 'soporte_api_falsa.dart';

void main() {
  testWidgets(
      'al pedir el cambio de contraseña muestra el correo de destino y '
      'avisa que la sesión se cerrará al cambiarla', (tester) async {
    final api = await montarConApi(
      tester,
      const VistaPerfil(rol: RolUsuario.estudiante),
      rutas: {
        'POST /autenticacion/solicitar-cambio-contrasena': {
          'message':
              'Si el correo existe, enviaremos instrucciones de recuperación.',
        },
      },
    );

    await tocarTexto(tester, 'Cambiar contraseña');

    expect(api.cuerpoDe('POST /autenticacion/solicitar-cambio-contrasena'),
        {'correo': 'persona@alumnos.ubiobio.cl'});
    expect(find.byType(DialogoCorreoEnviado), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('texto-envio')))
          .textSpan!
          .toPlainText(),
      'Te enviamos un enlace para cambiar tu contraseña.',
    );
    expect(
      find.descendant(
        of: find.byType(DialogoCorreoEnviado),
        matching: find.textContaining('persona@', findRichText: true),
      ),
      findsNothing,
    );
    expect(
        find.text('Al cambiarla, cerraremos tu sesión en todos tus equipos.'),
        findsOneWidget);

    await tocarTexto(tester, 'Entendido');

    expect(find.byType(DialogoCorreoEnviado), findsNothing);
  });
}
