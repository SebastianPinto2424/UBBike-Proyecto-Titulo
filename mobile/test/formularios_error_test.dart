import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/acceso/presentation/hoja_denegacion_qr.dart';
import 'package:ubbike/features/acceso/presentation/hoja_solicitar_atencion.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

const _bicicletero = BicicleteroApp(
  id: 'bicicletero-1',
  nombre: 'Bicicletero FACE',
  ubicacion: 'Sector FACE',
  capacidad: 20,
  ocupados: 5,
  cuposDisponibles: 15,
  porcentajeUso: 25,
);

Future<void> _abrirHoja(WidgetTester tester, Widget hoja) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: crearTemaUbb(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => hoja,
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('Solicitar atención', () {
    testWidgets('si el servidor la rechaza, muestra el motivo y sigue abierta',
        (tester) async {
      await _abrirHoja(
        tester,
        HojaSolicitarAtencion(
          bicicleteros: const [_bicicletero],
          onEnviar: (_, __) async => 'El guardia ya respondió esta solicitud',
        ),
      );

      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Solicitar atención'));
      await tester.pumpAndSettle();

      expect(
          find.text('El guardia ya respondió esta solicitud'), findsOneWidget);
      expect(find.byType(HojaSolicitarAtencion), findsOneWidget);
    });

    testWidgets('si se envía, se cierra', (tester) async {
      String? enviadoA;
      await _abrirHoja(
        tester,
        HojaSolicitarAtencion(
          bicicleteros: const [_bicicletero],
          onEnviar: (bicicleteroId, _) async {
            enviadoA = bicicleteroId;
            return null;
          },
        ),
      );

      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Solicitar atención'));
      await tester.pumpAndSettle();

      expect(enviadoA, 'bicicletero-1');
      expect(find.byType(HojaSolicitarAtencion), findsNothing);
    });
  });

  group('Rechazar un movimiento', () {
    testWidgets('pide elegir el motivo antes de enviar', (tester) async {
      var enviados = 0;
      await _abrirHoja(
        tester,
        HojaDenegacion(
          esIngreso: true,
          onConfirmar: (_) async {
            enviados++;
            return null;
          },
        ),
      );

      expect(find.text('Rechazar ingreso'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Rechazar'));
      await tester.pumpAndSettle();

      expect(find.text('Selecciona el motivo del rechazo.'), findsOneWidget);
      expect(enviados, 0);
    });

    testWidgets('envía el motivo elegido con el detalle opcional',
        (tester) async {
      String? enviado;
      await _abrirHoja(
        tester,
        HojaDenegacion(
          esIngreso: false,
          onConfirmar: (motivo) async {
            enviado = motivo;
            return null;
          },
        ),
      );

      await tester.tap(find.text('La bicicleta no coincide'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'Es de otro color');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Rechazar'));
      await tester.pumpAndSettle();

      expect(enviado, 'La bicicleta no coincide. Es de otro color');
      expect(find.byType(HojaDenegacion), findsNothing);
    });

    testWidgets('si el servidor lo impide, muestra el motivo en la hoja',
        (tester) async {
      await _abrirHoja(
        tester,
        HojaDenegacion(
          esIngreso: true,
          onConfirmar: (_) async => 'Este QR ya se usó',
        ),
      );

      await tester.tap(find.text('Los datos no coinciden con el titular'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Rechazar'));
      await tester.pumpAndSettle();

      expect(find.text('Este QR ya se usó'), findsOneWidget);
      expect(find.byType(HojaDenegacion), findsOneWidget);
    });
  });
}
