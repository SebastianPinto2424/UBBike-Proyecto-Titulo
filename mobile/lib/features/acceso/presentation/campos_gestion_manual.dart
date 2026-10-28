import 'package:flutter/material.dart';

import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/utilidades/opciones_bicicleta.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';

class CamposGestionManual {
  final nombre = TextEditingController();
  final correo = TextEditingController();
  final rut = TextEditingController();
  final comentario = TextEditingController();
  final descripcion = TextEditingController();
  final marca = TextEditingController();
  final modelo = TextEditingController();
  final color = TextEditingController();
  final aro = TextEditingController();
  final numeroSerie = TextEditingController();

  final focoCorreo = FocusNode();
  final focoRut = FocusNode();
  final focoNombre = FocusNode();
  final focoComentario = FocusNode();
  final focoDescripcion = FocusNode();
  final focoMarca = FocusNode();
  final focoModelo = FocusNode();
  final focoNumeroSerie = FocusNode();

  late final List<FocusNode> _focos = [
    focoCorreo,
    focoRut,
    focoNombre,
    focoComentario,
    focoDescripcion,
    focoMarca,
    focoModelo,
    focoNumeroSerie,
  ];
  late final List<TextEditingController> _bicicleta = [
    descripcion,
    marca,
    modelo,
    color,
    aro,
    numeroSerie,
  ];
  late final List<TextEditingController> _todos = [
    nombre,
    correo,
    rut,
    comentario,
    ..._bicicleta,
  ];

  void escucharFocos(VoidCallback alCambiar) {
    for (final foco in _focos) {
      foco.addListener(alCambiar);
    }
  }

  void dejarDeEscucharFocos(VoidCallback alCambiar) {
    for (final foco in _focos) {
      foco.removeListener(alCambiar);
    }
  }

  void cargarBicicleta(BicicletaApp bicicleta) {
    descripcion.text = bicicleta.descripcion;
    marca.text = bicicleta.marca ?? '';
    modelo.text = bicicleta.modelo ?? '';
    color.text =
        normalizarColorBicicleta(bicicleta.color) ?? bicicleta.color ?? '';
    aro.text = normalizarAroBicicleta(bicicleta.aro) ?? bicicleta.aro ?? '';
    numeroSerie.text = bicicleta.numeroSerie ?? '';
  }

  void limpiarBicicleta() {
    for (final campo in _bicicleta) {
      campo.clear();
    }
  }

  bool soltarIdentidadDe(UsuarioApp persona) {
    final mismoCorreo = correo.text.trim() == persona.correo;
    final mismoRut = rut.text.trim() == (persona.rut ?? '');
    if (mismoCorreo && mismoRut) {
      return false;
    }
    if (mismoCorreo) correo.clear();
    if (mismoRut) rut.clear();
    limpiarBicicleta();
    return true;
  }

  void limpiarTodo() {
    for (final campo in _todos) {
      campo.clear();
    }
  }

  String get colorNormalizado {
    final texto = color.text.trim();
    return normalizarColorBicicleta(texto) ?? texto;
  }

  String get aroNormalizado {
    final texto = aro.text.trim();
    return normalizarAroBicicleta(texto) ?? texto;
  }

  SolicitudRegistroManual solicitud({
    required String tipo,
    required String? bicicletaId,
    required String? bicicleteroId,
    required String? fotoUrl,
    required bool denegar,
    String? motivo,
  }) {
    return SolicitudRegistroManual(
      tipo: tipo,
      nombre: nombre.text.trim(),
      correo: correo.text.trim(),
      rut: rut.text.trim(),
      bicicletaId: bicicletaId,
      bicicleteroId: bicicleteroId,
      denegar: denegar,
      motivo: motivo,
      comentario: comentario.text.trim(),
      bicicletaDescripcion: descripcion.text.trim(),
      bicicletaMarca: marca.text.trim(),
      bicicletaModelo: modelo.text.trim(),
      bicicletaColor: colorNormalizado,
      bicicletaAro: aroNormalizado,
      bicicletaNumeroSerie: numeroSerie.text.trim(),
      bicicletaFotoUrl: fotoUrl,
      crearBicicletaNueva: bicicletaId == null,
    );
  }

  void dispose() {
    for (final foco in _focos) {
      foco.dispose();
    }
    for (final campo in _todos) {
      campo.dispose();
    }
  }
}

String? ayudaSiActivo(FocusNode foco, String texto) =>
    foco.hasFocus ? texto : null;
