import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ubbike/shared/widgets/boton_con_espera.dart';

class _Reloj {
  DateTime instante = DateTime(2026, 9, 22, 12);
  DateTime call() => instante;

  Future<void> avanzar(WidgetTester tester, int segundos) async {
    instante = instante.add(Duration(seconds: segundos));
    await tester.pump(Duration(seconds: segundos));
  }
}

Future<void> _montar(
  WidgetTester tester, {
  required int? segundos,
  _Reloj? reloj,
  VoidCallback? onPresionar,
  VoidCallback? alTerminar,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: BotonConEspera(
        segundosRestantes: segundos,
        prefijoEspera: 'Podrás recordar en',
        etiquetaLista: 'Recordar',
        icono: Icons.notifications_active_outlined,
        onPresionar: onPresionar ?? () {},
        alTerminarEspera: alTerminar,
        ahora: reloj?.call,
      ),
    ),
  ));
}

VoidCallback? _accion(WidgetTester tester) =>
    tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed;

void main() {
  testWidgets('sin espera el botón está activo', (tester) async {
    await _montar(tester, segundos: 0);

    expect(find.text('Recordar'), findsOneWidget);
    expect(_accion(tester), isNotNull);
  });

  testWidgets('null se trata como sin espera', (tester) async {
    await _montar(tester, segundos: null);

    expect(find.text('Recordar'), findsOneWidget);
    expect(_accion(tester), isNotNull);
  });

  testWidgets('la cuenta corre segundo a segundo y bloquea el botón',
      (tester) async {
    final reloj = _Reloj();
    await _montar(tester, segundos: 65, reloj: reloj);

    expect(find.text('Podrás recordar en 1:05'), findsOneWidget);
    expect(_accion(tester), isNull);

    await reloj.avanzar(tester, 1);
    expect(find.text('Podrás recordar en 1:04'), findsOneWidget);

    await reloj.avanzar(tester, 5);
    expect(find.text('Podrás recordar en 59s'), findsOneWidget);
  });

  testWidgets('bajo un minuto se muestra en segundos', (tester) async {
    await _montar(tester, segundos: 45, reloj: _Reloj());

    expect(find.text('Podrás recordar en 45s'), findsOneWidget);
  });

  testWidgets('al llegar a cero se habilita y avisa una sola vez',
      (tester) async {
    final reloj = _Reloj();
    var avisos = 0;
    await _montar(tester,
        segundos: 3, reloj: reloj, alTerminar: () => avisos++);

    expect(find.text('Podrás recordar en 3s'), findsOneWidget);

    await reloj.avanzar(tester, 3);

    expect(find.text('Recordar'), findsOneWidget);
    expect(_accion(tester), isNotNull);
    expect(avisos, 1);

    await reloj.avanzar(tester, 5);
    expect(avisos, 1);
  });

  testWidgets('una suspensión larga del equipo no deja la cuenta atrasada',
      (tester) async {
    final reloj = _Reloj();
    await _montar(tester, segundos: 300, reloj: reloj);

    reloj.instante = reloj.instante.add(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Recordar'), findsOneWidget);
    expect(_accion(tester), isNotNull);
  });

  testWidgets('presionar dispara la acción solo cuando terminó la espera',
      (tester) async {
    final reloj = _Reloj();
    var pulsaciones = 0;
    await _montar(tester,
        segundos: 2, reloj: reloj, onPresionar: () => pulsaciones++);

    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    expect(pulsaciones, 0);

    await reloj.avanzar(tester, 2);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    expect(pulsaciones, 1);
  });

  testWidgets('un valor nuevo del servidor reancla la cuenta', (tester) async {
    final reloj = _Reloj();
    await _montar(tester, segundos: 10, reloj: reloj);
    await reloj.avanzar(tester, 4);
    expect(find.text('Podrás recordar en 6s'), findsOneWidget);

    await _montar(tester, segundos: 30, reloj: reloj);
    expect(find.text('Podrás recordar en 30s'), findsOneWidget);
  });

  test('el formato usa minutos solo desde 60 segundos', () {
    expect(formatearEspera(59), '59s');
    expect(formatearEspera(60), '1:00');
    expect(formatearEspera(125), '2:05');
    expect(formatearEspera(300), '5:00');
  });
}
