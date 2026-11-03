import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/servicios/corrector_ortografico_servicio.dart';
import 'package:ubbike/core/servicios/diccionario_ortografico.dart';

final _diccionario = DiccionarioOrtografico(
  ['me', 'robaron', 'la', 'bicicleta', 'también', 'escriba', 'en', 'el'],
);

List<String> _marcadas(String texto) => [
      for (final marca in revisarOrtografia(_diccionario, texto))
        texto.substring(marca.range.start, marca.range.end),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('marca las palabras mal escritas con sus sugerencias', () {
    const texto = 'me robaron la bisicleta tambien';
    final marcas = revisarOrtografia(_diccionario, texto);

    expect(_marcadas(texto), ['bisicleta', 'tambien']);
    expect(marcas.first.suggestions, ['bicicleta']);
    expect(marcas.last.suggestions, ['también']);
  });

  test(
      'no marca nombres propios, siglas, correos, enlaces ni palabras pegadas '
      'a números', () {
    expect(
      _marcadas('Catalina escriba a ana@alumnos.ubiobio.cl en el '
          'www.ubbike.me 2do FACE'),
      isEmpty,
    );
  });

  test('solo revisa textos en español', () async {
    final servicio = CorrectorOrtograficoServicio(
        cargarDiccionario: () async => _diccionario);

    expect(
      await servicio.fetchSpellCheckSuggestions(
          const Locale('en'), 'bisicleta'),
      isNull,
    );
    expect(
      await servicio.fetchSpellCheckSuggestions(
          const Locale('es'), 'bisicleta'),
      hasLength(1),
    );
  });

  test('carga el diccionario una sola vez', () async {
    var cargas = 0;
    final servicio = CorrectorOrtograficoServicio(cargarDiccionario: () async {
      cargas++;
      return _diccionario;
    });

    await servicio.fetchSpellCheckSuggestions(const Locale('es'), 'uno');
    await servicio.fetchSpellCheckSuggestions(const Locale('es'), 'dos');

    expect(cargas, 1);
  });

  test('el diccionario de la app reconoce el español y las palabras de UBBike',
      () async {
    const texto =
        'tambien dejé mi bicicleta en el bicicletero por una incidencia';
    final marcas = await CorrectorOrtograficoServicio.instancia
        .fetchSpellCheckSuggestions(const Locale('es'), texto);

    expect(marcas!.single.range, const TextRange(start: 0, end: 7));
    expect(marcas.single.suggestions.first, 'también');
  });

  testWidgets('al tocar una palabra mal escrita muestra la sugerencia',
      (tester) async {
    final controlador = TextEditingController();
    addTearDown(controlador.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es')],
        home: Scaffold(
          body: TextField(
            controller: controlador,
            spellCheckConfiguration: SpellCheckConfiguration(
              spellCheckService: CorrectorOrtograficoServicio(
                cargarDiccionario: () async => _diccionario,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'bisicleta');
    await tester.pumpAndSettle();
    await tester.tapAt(
        tester.getTopLeft(find.byType(EditableText)) + const Offset(12, 8));
    await tester.pumpAndSettle();

    expect(find.byType(SpellCheckSuggestionsToolbar), findsOneWidget);
    await tester.tap(find.text('bicicleta'));
    await tester.pumpAndSettle();

    expect(controlador.text, 'bicicleta');
  });
}
