import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/autenticacion/application/autenticacion_vm.dart';
import 'package:ubbike/features/autenticacion/presentation/pantalla_cambio_obligatorio.dart';

const _claveSegura = 'Bicicleta#2026ubb';

class _SesionFalsa extends SesionNotifier {
  int cierres = 0;

  @override
  Future<EstadoSesion> build() async => const SesionVacia();

  @override
  Future<void> cerrar() async {
    cierres++;
    state = const AsyncData(SesionVacia());
  }
}

class _VmFalso extends AutenticacionVm {
  _VmFalso(super.ref, this.llamadas, {this.error});

  final List<Map<String, String>> llamadas;
  final Object? error;

  Future<T> _responder<T>(Map<String, String> datos, T valor) async {
    llamadas.add(datos);
    if (error != null) {
      throw error!;
    }
    return valor;
  }

  @override
  Future<String> cambiarContrasenaSesion({
    required String contrasenaActual,
    required String contrasenaNueva,
  }) =>
      _responder(
        {
          'accion': 'sesion',
          'actual': contrasenaActual,
          'nueva': contrasenaNueva,
        },
        'Contraseña actualizada',
      );
}

late _SesionFalsa _sesion;

Future<List<Map<String, String>>> _montar(
  WidgetTester tester,
  Widget pantalla, {
  Object? error,
}) async {
  final llamadas = <Map<String, String>>[];
  _sesion = _SesionFalsa();
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sesionProvider.overrideWith(() => _sesion),
        autenticacionVmProvider
            .overrideWith((ref) => _VmFalso(ref, llamadas, error: error)),
      ],
      child: MaterialApp(theme: crearTemaUbb(), home: pantalla),
    ),
  );
  await tester.pumpAndSettle();
  return llamadas;
}

Future<void> _tocar(WidgetTester tester, Finder boton) async {
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

Finder _campo(String etiqueta) => find.widgetWithText(TextField, etiqueta);

void main() {
  group('cambio obligatorio de contraseña', () {
    testWidgets('valida la nueva contraseña', (tester) async {
      final llamadas = await _montar(tester, const PantallaCambioObligatorio());

      await tester.enterText(_campo('Contraseña actual'), 'Temporal#2026x');
      await tester.enterText(_campo('Nueva contraseña'), 'corta');
      await _tocar(tester, find.text('Guardar y continuar'));

      expect(find.text('Mínimo 12 caracteres.'), findsOneWidget);
      expect(llamadas, isEmpty);
    });

    testWidgets('guarda la contraseña y cierra la sesión', (tester) async {
      final llamadas = await _montar(tester, const PantallaCambioObligatorio());

      await tester.enterText(_campo('Contraseña actual'), 'Temporal#2026x');
      await tester.enterText(_campo('Nueva contraseña'), _claveSegura);
      await tester.enterText(
        _campo('Confirmar nueva contraseña'),
        _claveSegura,
      );
      await _tocar(tester, find.text('Guardar y continuar'));

      expect(llamadas.single, {
        'accion': 'sesion',
        'actual': 'Temporal#2026x',
        'nueva': _claveSegura,
      });
      expect(_sesion.cierres, 1);
    });

    testWidgets('si la contraseña actual es incorrecta no cierra la sesión',
        (tester) async {
      await _montar(
        tester,
        const PantallaCambioObligatorio(),
        error: const ExcepcionApi('La contraseña actual no es correcta'),
      );

      await tester.enterText(_campo('Contraseña actual'), 'Equivocada#2026');
      await tester.enterText(_campo('Nueva contraseña'), _claveSegura);
      await tester.enterText(
        _campo('Confirmar nueva contraseña'),
        _claveSegura,
      );
      await _tocar(tester, find.text('Guardar y continuar'));

      expect(find.text('La contraseña actual no es correcta'), findsOneWidget);
      expect(_sesion.cierres, 0);
    });

    testWidgets('cada campo de contraseña tiene su propio ojo', (tester) async {
      await _montar(tester, const PantallaCambioObligatorio());
      bool oculto(String etiqueta) =>
          tester.widget<TextField>(_campo(etiqueta)).obscureText;

      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(3));

      await _tocar(
        tester,
        find.descendant(
          of: _campo('Confirmar nueva contraseña'),
          matching: find.byIcon(Icons.visibility_outlined),
        ),
      );

      expect(oculto('Confirmar nueva contraseña'), isFalse);
      expect(oculto('Nueva contraseña'), isTrue);
      expect(oculto('Contraseña actual'), isTrue);
    });

    testWidgets('permite cerrar sesión sin cambiarla', (tester) async {
      await _montar(tester, const PantallaCambioObligatorio());

      await _tocar(tester, find.text('Cerrar sesión'));

      expect(_sesion.cierres, 1);
    });
  });
}
