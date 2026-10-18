import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final archivos = _leerArchivos();

  test('core no depende de shared, de las features ni de app', () {
    final violaciones = [
      for (final archivo in archivos.where((a) => a.raiz == 'core'))
        for (final destino in archivo.imports)
          if (destino.raiz != 'core') '${archivo.ruta} -> ${destino.ruta}',
    ];
    expect(violaciones, isEmpty, reason: violaciones.join('\n'));
  });

  test('shared no depende de las features ni de app', () {
    final violaciones = [
      for (final archivo in archivos.where((a) => a.raiz == 'shared'))
        for (final destino in archivo.imports)
          if (destino.raiz == 'features' || destino.raiz == 'app')
            '${archivo.ruta} -> ${destino.ruta}',
    ];
    expect(violaciones, isEmpty, reason: violaciones.join('\n'));
  });

  test('las features no dependen de app', () {
    final violaciones = [
      for (final archivo in archivos.where((a) => a.feature != null))
        for (final destino in archivo.imports)
          if (destino.raiz == 'app') '${archivo.ruta} -> ${destino.ruta}',
    ];
    expect(violaciones, isEmpty, reason: violaciones.join('\n'));
  });

  test('una feature solo usa la capa data de otra feature', () {
    final violaciones = [
      for (final archivo in archivos.where((a) => a.feature != null))
        for (final destino in archivo.imports)
          if (destino.feature != null &&
              destino.feature != archivo.feature &&
              destino.capa != 'data')
            '${archivo.ruta} -> ${destino.ruta}',
    ];
    expect(violaciones, isEmpty, reason: violaciones.join('\n'));
  });

  test('dentro de una feature las capas solo apuntan hacia data', () {
    const permitidas = {
      'data': {'data'},
      'application': {'data', 'application'},
      'presentation': {'data', 'application', 'presentation'},
    };
    final violaciones = [
      for (final archivo in archivos.where((a) => a.feature != null))
        for (final destino in archivo.imports)
          if (destino.feature != null &&
              !permitidas[archivo.capa]!.contains(destino.capa))
            '${archivo.ruta} (${archivo.capa}) -> ${destino.ruta}',
    ];
    expect(violaciones, isEmpty, reason: violaciones.join('\n'));
  });

  test('las vistas leen datos a través de la capa de aplicación', () {
    final repositorio = RegExp(r'\b\w+RepositoryProvider\b');
    final violaciones = [
      for (final archivo in archivos.where((a) => a.esVista))
        for (final coincidencia in repositorio.allMatches(archivo.contenido))
          '${archivo.ruta}: ${coincidencia.group(0)}',
    ];
    expect(violaciones, isEmpty, reason: violaciones.join('\n'));
  });

  test('no hay dependencias circulares entre features', () {
    final grafo = <String, Set<String>>{};
    for (final archivo in archivos.where((a) => a.feature != null)) {
      final vecinos = grafo.putIfAbsent(archivo.feature!, () => {});
      for (final destino in archivo.imports) {
        if (destino.feature != null && destino.feature != archivo.feature) {
          vecinos.add(destino.feature!);
        }
      }
    }
    final ciclo = _buscarCiclo(grafo);
    expect(ciclo, isNull, reason: 'Ciclo: ${ciclo?.join(' -> ')}');
  });

  test('ningún archivo de lib supera las $_maximoLineas líneas', () {
    final violaciones = [
      for (final archivo in archivos)
        if (archivo.lineas > _maximoLineas)
          '${archivo.ruta}: ${archivo.lineas} líneas',
    ];
    expect(violaciones, isEmpty, reason: violaciones.join('\n'));
  });
}

const _maximoLineas = 500;

class _Ruta {
  _Ruta(this.ruta);

  final String ruta;

  List<String> get _partes => ruta.split('/');
  String get raiz => _partes.length == 1 ? 'main' : _partes.first;
  String? get feature => raiz == 'features' ? _partes[1] : null;
  String? get capa => raiz == 'features' ? _partes[2] : null;
}

class _Archivo extends _Ruta {
  _Archivo(super.ruta, this.contenido, this.imports);

  final String contenido;
  final List<_Ruta> imports;

  int get lineas => '\n'.allMatches(contenido).length;
  bool get esVista =>
      capa == 'presentation' ||
      raiz == 'app' ||
      ruta.startsWith('shared/widgets/');
}

List<_Archivo> _leerArchivos() {
  final lib = Directory('lib');
  final import = RegExp(r"^import 'package:ubbike/([^']+)';", multiLine: true);
  return [
    for (final entidad in lib.listSync(recursive: true))
      if (entidad is File && entidad.path.endsWith('.dart'))
        () {
          final ruta = entidad.path
              .substring(lib.path.length + 1)
              .replaceAll(Platform.pathSeparator, '/');
          final contenido = entidad.readAsStringSync();
          return _Archivo(ruta, contenido, [
            for (final m in import.allMatches(contenido)) _Ruta(m.group(1)!),
          ]);
        }(),
  ];
}

List<String>? _buscarCiclo(Map<String, Set<String>> grafo) {
  final estado = <String, int>{};
  final pila = <String>[];

  List<String>? visitar(String nodo) {
    estado[nodo] = 1;
    pila.add(nodo);
    for (final vecino in grafo[nodo] ?? const <String>{}) {
      if (estado[vecino] == 1) {
        return [...pila.sublist(pila.indexOf(vecino)), vecino];
      }
      if (estado[vecino] == null) {
        final ciclo = visitar(vecino);
        if (ciclo != null) return ciclo;
      }
    }
    pila.removeLast();
    estado[nodo] = 2;
    return null;
  }

  for (final nodo in grafo.keys) {
    if (estado[nodo] == null) {
      final ciclo = visitar(nodo);
      if (ciclo != null) return ciclo;
    }
  }
  return null;
}
