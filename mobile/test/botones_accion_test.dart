import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/acceso/presentation/botones_decision_movimiento.dart';
import 'package:ubbike/features/acceso/presentation/dialogo_nota_cierre.dart';
import 'package:ubbike/shared/widgets/botones_accion.dart';
import 'package:ubbike/shared/widgets/dialogo_eliminar.dart';

Future<void> _montar(WidgetTester tester, double ancho, Widget hijo) {
  return tester.pumpWidget(
    MaterialApp(
      theme: crearTemaUbb(),
      home: Scaffold(
        body: Center(child: SizedBox(width: ancho, child: hijo)),
      ),
    ),
  );
}

Color? _fondo(WidgetTester tester, String texto) {
  final boton = tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, texto),
  );
  return boton.style?.backgroundColor?.resolve(const <WidgetState>{});
}

Future<void> _abrirDialogo(
  WidgetTester tester,
  void Function(BuildContext context) abrir,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: crearTemaUbb(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => abrir(context),
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
  testWidgets('con espacio quedan lado a lado y del mismo ancho',
      (tester) async {
    await _montar(
      tester,
      400,
      BotonesAccion.confirmacion(
        textoConfirmar: 'Eliminar',
        onConfirmar: () {},
        onCancelar: () {},
      ),
    );

    final cancelar =
        tester.getRect(find.widgetWithText(ElevatedButton, 'Cancelar'));
    final eliminar =
        tester.getRect(find.widgetWithText(ElevatedButton, 'Eliminar'));
    expect(cancelar.top, eliminar.top);
    expect(cancelar.width, eliminar.width);
    expect(cancelar.right, lessThan(eliminar.left));
    expect(cancelar.height, 50);
  });

  testWidgets(
      'en el ingreso confirmar va a la izquierda y rechazar a la derecha',
      (tester) async {
    await _montar(
      tester,
      640,
      BotonesDecisionMovimiento(
        esIngreso: true,
        procesando: false,
        habilitado: true,
        onConfirmar: () {},
        onRechazar: () {},
        textoSecundario: 'Escanear nuevamente',
        iconoSecundario: Icons.qr_code_scanner,
        onSecundario: () {},
      ),
    );

    final confirmar = tester
        .getRect(find.widgetWithText(ElevatedButton, 'Confirmar ingreso'));
    final rechazar =
        tester.getRect(find.widgetWithText(ElevatedButton, 'Rechazar ingreso'));
    expect(confirmar.top, rechazar.top);
    expect(confirmar.right, lessThan(rechazar.left));
    expect(_fondo(tester, 'Confirmar ingreso'), ColoresUbb.azulApp);
    expect(_fondo(tester, 'Rechazar ingreso'), ColoresUbb.rojoInstitucional);
  });

  testWidgets('si el texto no cabe se apilan sin achicar la letra',
      (tester) async {
    await _montar(
      tester,
      300,
      BotonesAccion(
        secundaria: AccionBoton(
          texto: 'Rechazar ingreso',
          color: ColoresUbb.rojoInstitucional,
          icono: Icons.block,
          onPressed: () {},
        ),
        principal: AccionBoton(
          texto: 'Confirmar ingreso',
          color: ColoresUbb.azulApp,
          icono: Icons.check_circle_outline,
          onPressed: () {},
        ),
      ),
    );

    final confirmar = tester
        .getRect(find.widgetWithText(ElevatedButton, 'Confirmar ingreso'));
    final rechazar =
        tester.getRect(find.widgetWithText(ElevatedButton, 'Rechazar ingreso'));
    expect(confirmar.bottom, lessThan(rechazar.top));
    expect(confirmar.width, 300);
    expect(rechazar.width, 300);
    expect(
      find.descendant(
        of: find.byType(BotonesAccion),
        matching: find.byType(FittedBox),
      ),
      findsNothing,
    );
  });

  testWidgets('el rojo marca la opcion negativa de cada par', (tester) async {
    await _montar(
      tester,
      400,
      Column(
        children: [
          BotonesAccion.confirmacion(
            destructiva: true,
            textoConfirmar: 'Eliminar',
            onConfirmar: () {},
            onCancelar: () {},
          ),
          BotonesAccion.confirmacion(
            textoCancelar: 'Repetir',
            textoConfirmar: 'Usar foto',
            onConfirmar: () {},
            onCancelar: () {},
          ),
        ],
      ),
    );

    expect(_fondo(tester, 'Eliminar'), ColoresUbb.rojoInstitucional);
    expect(_fondo(tester, 'Cancelar'), ColoresUbb.azulApp);
    expect(_fondo(tester, 'Usar foto'), ColoresUbb.azulApp);
    expect(_fondo(tester, 'Repetir'), ColoresUbb.rojoInstitucional);
  });

  testWidgets('la confirmacion de eliminacion devuelve la eleccion',
      (tester) async {
    Future<bool>? resultado;
    void abrir(BuildContext context) => resultado = confirmarEliminacion(
          context,
          titulo: 'Eliminar cuenta',
          nombre: 'Ana Pérez',
          consecuencia: 'Se desactivará la cuenta.',
        );

    await _abrirDialogo(tester, abrir);
    expect(find.text('Ana Pérez'), findsOneWidget);
    await tester.tap(find.byKey(const Key('eliminar-confirmar')));
    await tester.pumpAndSettle();
    expect(await resultado, isTrue);
    expect(find.text('Ana Pérez'), findsNothing);

    await _abrirDialogo(tester, abrir);
    await tester.tap(find.byKey(const Key('eliminar-cancelar')));
    await tester.pumpAndSettle();
    expect(await resultado, isFalse);
  });

  testWidgets('la nota de cierre exige motivo y lo devuelve', (tester) async {
    Future<String?>? resultado;
    await _abrirDialogo(
      tester,
      (context) => resultado = showDialog<String>(
        context: context,
        builder: (_) => const DialogoNotaCierre(estado: 'RESUELTA'),
      ),
    );

    expect(_fondo(tester, 'Cancelar'), ColoresUbb.rojoInstitucional);
    expect(_fondo(tester, 'Confirmar'), ColoresUbb.azulApp);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
    await tester.pump();
    expect(find.text('Escribe un motivo para cerrar la solicitud.'),
        findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Resuelto en terreno');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar'));
    await tester.pumpAndSettle();
    expect(await resultado, 'Resuelto en terreno');
  });
}
