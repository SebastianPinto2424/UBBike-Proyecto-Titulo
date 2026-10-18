import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/configuracion/rutas_app.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/auth/application/autenticacion_vm.dart';
import 'package:ubbike/features/auth/data/autenticacion_api.dart';
import 'package:ubbike/features/auth/presentation/pantalla_login.dart';

const _usuario = UsuarioApp(
  id: 'usuario-1',
  nombre: 'Ana Pérez',
  correo: 'ana@alumnos.ubiobio.cl',
  rol: RolUsuario.estudiante,
  correoVerificado: true,
  registroParcial: false,
  cuentaActiva: true,
);

class _SesionSinAlmacen extends SesionNotifier {
  @override
  Future<SesionState> build() async => const SesionVacia();

  @override
  Future<void> iniciar({
    required String token,
    required UsuarioApp usuario,
    String? refreshToken,
  }) async {
    state = AsyncData(SesionActiva(usuario: usuario, token: token));
  }
}

class _VmLoginExitoso extends AutenticacionVm {
  _VmLoginExitoso(super.ref);

  @override
  Future<ResultadoLogin> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async =>
      const ResultadoLogin(token: 'token', usuario: _usuario);
}

void main() {
  testWidgets(
      'tras cambiar la contraseña, iniciar sesión lleva al inicio aunque el '
      'login se haya abierto fuera de la raíz', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sesionProvider.overrideWith(_SesionSinAlmacen.new),
          autenticacionVmProvider.overrideWith((ref) => _VmLoginExitoso(ref)),
        ],
        child: MaterialApp(
          theme: crearTemaUbb(),
          onGenerateInitialRoutes: (_) => [
            MaterialPageRoute(
              builder: (_) => const PantallaLogin(
                mensajeInicial: 'Contraseña actualizada.',
              ),
            ),
          ],
          onGenerateRoute: (ajustes) => MaterialPageRoute(
            settings: ajustes,
            builder: (_) => Text('raíz ${ajustes.name}'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'ana@alumnos.ubiobio.cl',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'ClaveSegura#2026',
    );
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('raíz $rutaRaiz'), findsOneWidget);
    expect(find.byType(PantallaLogin), findsNothing);
  });
}
