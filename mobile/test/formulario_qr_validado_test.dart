import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:ubbike/features/acceso/presentation/formulario_qr_validado.dart';
import 'package:ubbike/shared/widgets/campo_solo_lectura.dart';

QrValidadoApp _qr(String tipo) => QrValidadoApp(
      token: 'UBBIKE-prueba',
      tipo: tipo,
      expiraEn: DateTime(2026, 10, 16, 15, 30),
      usuarioNombre: 'Ana Pérez',
      usuarioCorreo: 'ana@alumnos.ubiobio.cl',
      usuarioRut: '11.111.111-1',
      bicicletaDescripcion: 'Bici roja',
    );

Future<void> _montar(WidgetTester tester, QrValidadoApp qr,
    {VoidCallback? onConfirmar, VoidCallback? onDenegar}) async {
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: crearTemaUbb(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: FormularioQrValidado(
            claveFormulario: GlobalKey<FormState>(),
            qr: qr,
            controladorComentario: TextEditingController(),
            onConfirmar: onConfirmar ?? () {},
            onDenegar: onDenegar ?? () {},
            onLeerOtro: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('muestra la acción y sus botones sin desbordar', (tester) async {
    var confirmado = 0;
    var denegado = 0;
    await _montar(
      tester,
      _qr('RETIRO'),
      onConfirmar: () => confirmado++,
      onDenegar: () => denegado++,
    );

    expect(find.text('Autorizar retiro'), findsOneWidget);
    expect(find.text('Bicicletero de tu turno'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Confirmar retiro'));
    await tester.tap(find.text('Confirmar retiro'));
    await tester.tap(find.text('Rechazar retiro'));
    expect(confirmado, 1);
    expect(denegado, 1);
  });

  testWidgets(
      'los datos del QR se ven como solo lectura y solo el comentario se '
      'edita', (tester) async {
    await _montar(tester, _qr('INGRESO'));

    expect(find.byType(CampoSoloLectura), findsNWidgets(10));
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.widgetWithText(CampoSoloLectura, 'Ana Pérez'), findsOneWidget);
    expect(find.widgetWithText(CampoSoloLectura, 'Sin marca'), findsOneWidget);

    await tester.tap(find.widgetWithText(CampoSoloLectura, 'Ana Pérez'));
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isFalse);

    final comentario =
        find.widgetWithText(TextFormField, 'Comentario opcional del guardia');
    await tester.ensureVisible(comentario);
    await tester.enterText(comentario, 'Trae candado');
    expect(find.text('Trae candado'), findsOneWidget);
  });
}
