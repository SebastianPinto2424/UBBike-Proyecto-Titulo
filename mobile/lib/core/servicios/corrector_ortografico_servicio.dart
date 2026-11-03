import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';

import 'package:ubbike/core/servicios/diccionario_ortografico.dart';

const _listasDePalabras = [
  'assets/ortografia/palabras_es.txt',
  'assets/ortografia/palabras_ubbike.txt',
];

final _patronPalabra = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+');
final _patronDireccion = RegExp(r'@|://|www\.|\w\.\w');
final _patronDigito = RegExp(r'[0-9_]');
final _patronEspacio = RegExp(r'\s');

class CorrectorOrtograficoServicio implements SpellCheckService {
  CorrectorOrtograficoServicio({
    Future<DiccionarioOrtografico> Function()? cargarDiccionario,
  }) : _cargarDiccionario = cargarDiccionario ?? _cargarDesdeRecursos;

  static final instancia = CorrectorOrtograficoServicio();

  final Future<DiccionarioOrtografico> Function() _cargarDiccionario;
  Future<DiccionarioOrtografico>? _diccionario;

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    if (locale.languageCode != 'es') return null;
    final diccionario = await (_diccionario ??= _cargarDiccionario());
    return revisarOrtografia(diccionario, text);
  }
}

List<SuggestionSpan> revisarOrtografia(
  DiccionarioOrtografico diccionario,
  String texto,
) =>
    [
      for (final coincidencia in _patronPalabra.allMatches(texto))
        if (!_seOmite(texto, coincidencia) &&
            !diccionario.contiene(coincidencia[0]!))
          SuggestionSpan(
            TextRange(start: coincidencia.start, end: coincidencia.end),
            diccionario.sugerencias(coincidencia[0]!),
          ),
    ];

bool _seOmite(String texto, Match coincidencia) {
  final palabra = coincidencia[0]!;
  if (palabra.length < 2 || palabra[0] != palabra[0].toLowerCase()) {
    return true;
  }

  final anterior = coincidencia.start > 0 ? texto[coincidencia.start - 1] : '';
  final siguiente =
      coincidencia.end < texto.length ? texto[coincidencia.end] : '';
  if (_patronDigito.hasMatch(anterior) || _patronDigito.hasMatch(siguiente)) {
    return true;
  }

  final inicio = texto.lastIndexOf(_patronEspacio, coincidencia.start) + 1;
  final espacioSiguiente = texto.indexOf(_patronEspacio, coincidencia.end);
  final fin = espacioSiguiente == -1 ? texto.length : espacioSiguiente;
  return _patronDireccion.hasMatch(texto.substring(inicio, fin));
}

Future<DiccionarioOrtografico> _cargarDesdeRecursos() async {
  final palabras = <String>[];
  for (final lista in _listasDePalabras) {
    final datos = await rootBundle.load(lista);
    palabras.addAll(
      const LineSplitter().convert(
        utf8.decode(
          datos.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes),
        ),
      ),
    );
  }
  return DiccionarioOrtografico(palabras);
}
