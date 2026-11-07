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
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/widgets/campo_solo_lectura.dart';

import 'soporte_api_falsa.dart';

const _avisoDatosBloqueados =
    'Datos de la bicicleta registrada: en un retiro no se pueden cambiar.';

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
  Future<EstadoSesion> build() async =>
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

class _VmRegistro extends _VmConCoincidencia {
  _VmRegistro(super.ref, this.solicitudes);

  final List<SolicitudRegistroManual> solicitudes;

  @override
  Future<MovimientoApp> registrarManual(
    SolicitudRegistroManual solicitud,
  ) async {
    solicitudes.add(solicitud);
    return MovimientoApp(
      id: 'movimiento-1',
      tipo: solicitud.tipo,
      estado: solicitud.denegar ? 'DENEGADO' : 'CONFIRMADO',
      origen: 'MANUAL',
      creadoEn: DateTime(2026, 11, 7, 10),
      usuarioNombre: 'Ana Pérez',
      usuarioCorreo: 'ana@alumnos.ubiobio.cl',
      usuarioRut: '11.111.111-1',
      bicicletaDescripcion: 'Bici roja',
      bicicleteroNombre: 'Bicicletero cercano a la FACE',
      guardiaNombre: 'Guardia',
    );
  }
}

bool _hayCampoConFoco() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>() !=
    null;

Future<void> _buscarAna(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Correo institucional'),
    'ana@alumnos.ubiobio.cl',
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

Future<void> _escribirComentario(WidgetTester tester, String texto) async {
  final comentario =
      find.widgetWithText(TextFormField, 'Comentario opcional del guardia');
  await tester.ensureVisible(comentario);
  await tester.pumpAndSettle();
  await tester.enterText(comentario, texto);
  await tester.pump();
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

  testWidgets(
      'en un retiro los datos registrados se leen bien, sin campos en gris y '
      'con un solo aviso', (tester) async {
    await _montar(tester);
    await _buscarAna(tester);

    expect(find.text(_avisoDatosBloqueados), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithText(CampoSoloLectura, 'Ana Pérez'), findsOneWidget);
    expect(find.widgetWithText(CampoSoloLectura, 'Trek'), findsOneWidget);
    expect(find.widgetWithText(CampoSoloLectura, 'Sin color'), findsOneWidget);
    expect(find.widgetWithText(CampoSoloLectura, 'Sin aro'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.enabled == false,
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DropdownButton && widget.onChanged == null,
      ),
      findsNothing,
    );

    final marca = find.widgetWithText(CampoSoloLectura, 'Trek');
    await tester.tap(marca);
    await tester.pump();
    final campoMarca = tester.widget<EditableText>(
      find.descendant(of: marca, matching: find.byType(EditableText)),
    );
    expect(campoMarca.focusNode.hasFocus, isFalse);
    expect(campoMarca.readOnly, isTrue);
  });

  testWidgets('cancelar suelta el cursor del comentario', (tester) async {
    await _montar(tester);
    await _buscarAna(tester);
    await _escribirComentario(tester, 'Usuario con U-Lock');
    expect(_hayCampoConFoco(), isTrue);

    await tocarTexto(tester, 'Cancelar acción');

    expect(_hayCampoConFoco(), isFalse);
    expect(find.text('Usuario con U-Lock'), findsNothing);
  });

  testWidgets(
      'confirmar un retiro registra la bicicleta bloqueada y el cursor no '
      'vuelve al comentario al cerrar el aviso', (tester) async {
    final solicitudes = <SolicitudRegistroManual>[];
    await _montar(
      tester,
      crearVm: (ref) => _VmRegistro(ref, solicitudes),
    );
    await _buscarAna(tester);
    await _escribirComentario(tester, 'Usuario con U-Lock');

    await tocar(tester, find.text('Confirmar retiro'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(solicitudes, hasLength(1));
    expect(solicitudes.single.tipo, 'RETIRO');
    expect(solicitudes.single.bicicletaId, 'bici-1');
    expect(solicitudes.single.comentario, 'Usuario con U-Lock');
    expect(_hayCampoConFoco(), isFalse);
    expect(find.text('Confirmar ingreso'), findsOneWidget);
  });

  testWidgets('al cerrar la hoja de rechazo el cursor no vuelve al comentario',
      (tester) async {
    await _montar(tester);
    await _buscarAna(tester);
    await _escribirComentario(tester, 'Revisar el candado');

    await tocarTexto(tester, 'Rechazar retiro');
    expect(find.text('La bicicleta no coincide'), findsOneWidget);
    expect(_hayCampoConFoco(), isFalse);

    await tocarTexto(tester, 'Cancelar');

    expect(find.text('La bicicleta no coincide'), findsNothing);
    expect(_hayCampoConFoco(), isFalse);
    expect(find.text('Revisar el candado'), findsOneWidget);
  });

  testWidgets('registrar otra bicicleta deja el cursor en la descripción',
      (tester) async {
    await _montar(tester);
    await _buscarAna(tester);

    await tocarTexto(tester, 'Registrar otra bicicleta');

    final descripcion = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Descripción'),
        matching: find.byType(EditableText),
      ),
    );
    expect(descripcion.focusNode.hasFocus, isTrue);
    expect(descripcion.readOnly, isFalse);
    expect(find.text(_avisoDatosBloqueados), findsNothing);
    expect(find.text('Confirmar ingreso'), findsOneWidget);
  });
}
