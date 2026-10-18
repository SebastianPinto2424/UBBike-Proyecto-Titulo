import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/acceso/application/gestion_manual_vm.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:ubbike/features/acceso/presentation/vista_gestion_manual_guardia.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';

const _guardia = UsuarioApp(
  id: 'guardia-1',
  nombre: 'Guardia',
  correo: 'guardia@ubiobio.cl',
  rol: RolUsuario.guardia,
  correoVerificado: true,
  registroParcial: false,
  cuentaActiva: true,
);

const _usuario = UsuarioApp(
  id: 'usuario-1',
  nombre: 'Ana Pérez',
  correo: 'ana@alumnos.ubiobio.cl',
  rut: '11.111.111-1',
  rol: RolUsuario.estudiante,
  correoVerificado: true,
  registroParcial: false,
  cuentaActiva: true,
);

class _SesionGuardia extends SesionNotifier {
  @override
  Future<SesionState> build() async =>
      const SesionActiva(usuario: _guardia, token: 'test');
}

class _VmConCoincidencia extends GestionManualVm {
  _VmConCoincidencia(super.ref);

  @override
  Future<CoincidenciaManualApp?> buscarCoincidencia({
    required String correo,
    required String rut,
  }) async =>
      const CoincidenciaManualApp(
        usuario: _usuario,
        bicicletas: [
          BicicletaApp(
            id: 'bici-1',
            descripcion: 'Bici roja',
            activa: true,
            dentroBicicletero: true,
            marca: 'Trek',
          ),
        ],
      );
}

const _beto = UsuarioApp(
  id: 'usuario-2',
  nombre: 'Beto Rojas',
  correo: 'beto@alumnos.ubiobio.cl',
  rut: '22.222.222-2',
  rol: RolUsuario.estudiante,
  correoVerificado: true,
  registroParcial: false,
  cuentaActiva: true,
);

class _VmDirectorio extends GestionManualVm {
  _VmDirectorio(super.ref);

  @override
  Future<CoincidenciaManualApp?> buscarCoincidencia({
    required String correo,
    required String rut,
  }) async {
    for (final persona in const [_usuario, _beto]) {
      if ((correo.isNotEmpty && correo == persona.correo) ||
          (rut.isNotEmpty && rut == persona.rut)) {
        return CoincidenciaManualApp(usuario: persona, bicicletas: const []);
      }
    }
    return null;
  }
}

Future<void> _montar(
  WidgetTester tester, {
  GestionManualVm Function(Ref ref) crearVm = _VmConCoincidencia.new,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionProvider.overrideWith(_SesionGuardia.new),
        gestionManualVmProvider.overrideWith(crearVm),
        bicicleterosGestionManualProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        theme: crearTemaUbb(),
        home: const Scaffold(body: VistaGestionManualGuardia()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra las secciones del formulario', (tester) async {
    await _montar(tester);

    expect(find.text('Datos de usuario'), findsOneWidget);
    expect(find.text('Datos de bicicleta'), findsOneWidget);
    expect(find.text('Confirmar ingreso'), findsOneWidget);
    expect(find.text('Cancelar acción'), findsOneWidget);
  });

  testWidgets(
      'al encontrar a la persona autocompleta sus datos y detecta el retiro',
      (tester) async {
    await _montar(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo institucional'),
      'ana@alumnos.ubiobio.cl',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Retiro detectado'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Bici roja'), findsWidgets);
    expect(find.text('Trek'), findsWidgets);
    expect(find.text('Confirmar retiro'), findsOneWidget);
  });

  testWidgets('cancelar limpia el formulario', (tester) async {
    await _montar(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo institucional'),
      'ana@alumnos.ubiobio.cl',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cancelar acción'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar acción'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Pérez'), findsNothing);
    expect(find.text('Bici roja'), findsNothing);
    expect(find.text('Confirmar ingreso'), findsOneWidget);
  });

  testWidgets(
      'si el guardia corrige el RUT, busca a la nueva persona en vez de volver '
      'a la anterior', (tester) async {
    await _montar(tester, crearVm: _VmDirectorio.new);
    final campoRut = find.widgetWithText(TextFormField, 'RUT');

    await tester.enterText(campoRut, '11.111.111-1');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('ana@alumnos.ubiobio.cl'), findsOneWidget);

    await tester.enterText(campoRut, '22.222.222-2');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Beto Rojas'), findsOneWidget);
    expect(find.text('22.222.222-2'), findsOneWidget);
    expect(find.text('beto@alumnos.ubiobio.cl'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsNothing);
  });
}
