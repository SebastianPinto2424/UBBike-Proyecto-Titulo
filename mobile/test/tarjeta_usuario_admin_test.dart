import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/admin/presentation/tarjeta_usuario_admin.dart';

const _usuario = UsuarioApp(
  id: 'u1',
  nombre: 'Ana Rojas',
  correo: 'ana@alumnos.ubiobio.cl',
  rut: '11.111.111-1',
  rol: RolUsuario.estudiante,
  correoVerificado: true,
  registroParcial: false,
  cuentaActiva: true,
);

class _Registro {
  final cambios = <Map<String, Object?>>[];
  final reenvios = <String>[];
  final ediciones = <String>[];
  final eliminaciones = <String>[];
}

Future<_Registro> _montar(WidgetTester tester, UsuarioApp usuario) async {
  final registro = _Registro();
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: crearTemaUbb(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: TarjetaUsuarioAdmin(
            usuario: usuario,
            onActualizar: (u, {rol, cuentaActiva}) async => registro.cambios
                .add({'id': u.id, 'rol': rol, 'cuentaActiva': cuentaActiva}),
            onReenviarCorreoCuenta: (u) async => registro.reenvios.add(u.id),
            onEditarCredenciales: (u) async => registro.ediciones.add(u.id),
            onEliminar: (u) async => registro.eliminaciones.add(u.id),
          ),
        ),
      ),
    ),
  );
  return registro;
}

Future<void> _abrir(WidgetTester tester) async {
  await tester.tap(find.text('Ana Rojas'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cerrada muestra solo el resumen de la cuenta', (tester) async {
    await _montar(tester, _usuario);

    expect(find.text('ana@alumnos.ubiobio.cl'), findsOneWidget);
    expect(find.text('Estudiante'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
    expect(find.text('Correo verificado'), findsOneWidget);
    expect(find.text('Eliminar cuenta'), findsNothing);
  });

  testWidgets('indica acceso denegado y activación pendiente', (tester) async {
    await _montar(
      tester,
      const UsuarioApp(
        id: 'g1',
        nombre: 'Pedro Soto',
        correo: 'guardia@ubiobio.cl',
        rol: RolUsuario.guardia,
        correoVerificado: false,
        registroParcial: false,
        cuentaActiva: false,
        debeCambiarContrasena: true,
      ),
    );

    expect(find.text('Acceso denegado'), findsOneWidget);
    expect(find.text('Acceso pendiente'), findsOneWidget);
  });

  testWidgets('al abrirla muestra los datos y las acciones', (tester) async {
    final registro = await _montar(tester, _usuario);
    await _abrir(tester);

    expect(find.text('11.111.111-1'), findsOneWidget);
    expect(find.text('Acceso habilitado'), findsOneWidget);
    expect(find.text('Reenviar verificación'), findsNothing);
    expect(find.text('Rol'), findsOneWidget);
    expect(find.text('Rol principal'), findsNothing);

    await tester.ensureVisible(find.text('Editar datos'));
    await tester.tap(find.text('Editar datos'));
    await tester.tap(find.text('Eliminar cuenta'));
    await tester.pump();

    expect(registro.ediciones, ['u1']);
    expect(registro.eliminaciones, ['u1']);
  });

  testWidgets('el interruptor deniega el acceso', (tester) async {
    final registro = await _montar(tester, _usuario);
    await _abrir(tester);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(registro.cambios, [
      {'id': 'u1', 'rol': null, 'cuentaActiva': false},
    ]);
  });

  testWidgets('permite reenviar el correo si falta verificar', (tester) async {
    final registro = await _montar(
      tester,
      const UsuarioApp(
        id: 'u2',
        nombre: 'Ana Rojas',
        correo: 'ana@alumnos.ubiobio.cl',
        rol: RolUsuario.estudiante,
        correoVerificado: false,
        registroParcial: false,
        cuentaActiva: true,
      ),
    );
    await _abrir(tester);

    await tester.tap(find.text('Reenviar verificación'));
    await tester.pump();

    expect(registro.reenvios, ['u2']);
  });

  testWidgets('cambiar el rol pide confirmación', (tester) async {
    final registro = await _montar(tester, _usuario);
    await _abrir(tester);

    await tester.ensureVisible(find.text('Estudiante').last);
    await tester.tap(find.text('Estudiante').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardia').last);
    await tester.pumpAndSettle();

    expect(find.text('Confirmar cambio de rol'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(registro.cambios, isEmpty);

    await tester.tap(find.text('Estudiante').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardia').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar rol'));
    await tester.pumpAndSettle();

    expect(registro.cambios, [
      {'id': 'u1', 'rol': RolUsuario.guardia, 'cuentaActiva': null},
    ]);
  });

  testWidgets(
      'en un telefono angosto editar y eliminar tienen el mismo tamaño y '
      'la misma letra', (tester) async {
    final registro = await _montar(tester, _usuario);
    tester.view.devicePixelRatio = 3.0;
    await tester.pump();
    await _abrir(tester);

    final botonEditar = find.byKey(const Key('editar-usuario-u1'));
    final botonEliminar = find.byKey(const Key('eliminar-usuario-u1'));
    final editar = tester.getRect(botonEditar);
    final eliminar = tester.getRect(botonEliminar);
    expect(editar.size, eliminar.size);
    expect(editar.overlaps(eliminar), isFalse);

    double altoTexto(Finder boton) => tester
        .getRect(find.descendant(of: boton, matching: find.byType(RichText)))
        .height;
    expect(altoTexto(botonEditar), altoTexto(botonEliminar));

    await tester.ensureVisible(botonEliminar);
    await tester.tap(botonEliminar);
    expect(registro.eliminaciones, ['u1']);
  });
}
