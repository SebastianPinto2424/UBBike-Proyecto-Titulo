import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/shared/widgets/contenedor_responsivo.dart';

class _Contador extends StatefulWidget {
  const _Contador();

  @override
  State<_Contador> createState() => _ContadorState();
}

class _ContadorState extends State<_Contador> {
  int valor = 0;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => setState(() => valor++),
        child: Text('valor $valor'),
      );
}

Widget _app(double anchoMaximo) => MaterialApp(
      home: Scaffold(
        body: ContenedorResponsivo(
          anchoMaximo: anchoMaximo,
          child: const _Contador(),
        ),
      ),
    );

void main() {
  testWidgets(
      'al pasar de ancho completo (inicio) a acotado y volver, el contenido '
      'conserva su estado', (tester) async {
    await tester.pumpWidget(_app(double.infinity));
    await tester.tap(find.text('valor 0'));
    await tester.pump();

    await tester.pumpWidget(_app(940));
    await tester.pumpWidget(_app(double.infinity));

    expect(find.text('valor 1'), findsOneWidget);
  });
}
