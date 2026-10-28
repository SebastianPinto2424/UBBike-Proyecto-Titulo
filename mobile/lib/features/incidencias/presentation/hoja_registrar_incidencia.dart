import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/incidencias/data/borrador_incidencia.dart';
import 'package:ubbike/features/incidencias/presentation/formulario_incidencia.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/servicios/captura_fotos.dart';
import 'package:ubbike/shared/utilidades/limites_foto.dart';

class HojaRegistrarIncidencia extends StatefulWidget {
  const HojaRegistrarIncidencia({
    super.key,
    required this.bicicleteros,
    required this.bicicletas,
    required this.permitirBicicletaPropia,
    required this.onEnviar,
    this.borrador,
  });

  final List<BicicleteroApp> bicicleteros;
  final List<BicicletaApp> bicicletas;
  final bool permitirBicicletaPropia;
  final BorradorIncidencia? borrador;

  final Future<String?> Function({
    required String bicicleteroId,
    required String tipo,
    required String descripcion,
    String? bicicletaId,
    List<String> fotos,
  }) onEnviar;

  @override
  State<HojaRegistrarIncidencia> createState() =>
      _HojaRegistrarIncidenciaState();
}

class _HojaRegistrarIncidenciaState extends State<HojaRegistrarIncidencia> {
  final formKeyIncidencia = GlobalKey<FormState>();
  final descripcionController = TextEditingController();
  final capturaFotos = CapturaFotos();
  final fotos = <String>[];
  BicicleteroApp? bicicleteroSeleccionado;
  BicicletaApp? bicicletaSeleccionada;
  String tipoSeleccionado = 'OTRO';
  bool enviando = false;
  String? error;

  @override
  void initState() {
    super.initState();
    bicicleteroSeleccionado =
        widget.bicicleteros.isEmpty ? null : widget.bicicleteros.first;
    final borrador = widget.borrador;
    if (borrador != null) {
      _restaurar(borrador);
    }
    unawaited(_recuperarFotoPerdida());
  }

  void _restaurar(BorradorIncidencia borrador) {
    for (final bicicletero in widget.bicicleteros) {
      if (bicicletero.id == borrador.bicicleteroId) {
        bicicleteroSeleccionado = bicicletero;
      }
    }
    for (final bicicleta in widget.bicicletas) {
      if (bicicleta.id == borrador.bicicletaId) {
        bicicletaSeleccionada = bicicleta;
      }
    }
    tipoSeleccionado = borrador.tipo;
    descripcionController.text = borrador.descripcion;
    fotos.addAll(borrador.fotos.take(maximoFotosIncidencia));
  }

  Future<void> _recuperarFotoPerdida() async {
    try {
      _aplicarFoto(
        await capturaFotos.recuperarPerdida(
          maximoBytes: maximoBytesFotoIncidencia,
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(borrarBorradorIncidencia());
    descripcionController.dispose();
    super.dispose();
  }

  Future<void> _guardarBorrador() => guardarBorradorIncidencia(
        BorradorIncidencia(
          bicicleteroId: bicicleteroSeleccionado?.id,
          bicicletaId: bicicletaSeleccionada?.id,
          tipo: tipoSeleccionado,
          descripcion: descripcionController.text,
          fotos: List<String>.of(fotos),
        ),
      );

  Future<void> _seleccionarFoto(ImageSource origen) async {
    if (fotos.length >= maximoFotosIncidencia) {
      return;
    }

    try {
      await _guardarBorrador();
      if (!mounted) {
        return;
      }
      _aplicarFoto(
        await capturaFotos.elegir(
          context,
          origen,
          calidad: 80,
          ladoMaximo: 1280,
          maximoBytes: maximoBytesFotoIncidencia,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = 'No se pudo cargar la foto.');
      }
    }
  }

  void _aplicarFoto(FotoPreparada? foto) {
    if (foto == null || !mounted || fotos.length >= maximoFotosIncidencia) {
      return;
    }
    final dataUrl = foto.dataUrl;
    if (dataUrl == null) {
      setState(() => error = foto.error ?? 'No se pudo cargar la foto.');
      return;
    }
    setState(() {
      fotos.add(dataUrl);
      error = null;
    });
  }

  Future<void> _enviar() async {
    final bicicletero = bicicleteroSeleccionado;
    final descripcion = descripcionController.text.trim();

    if (bicicletero == null ||
        formKeyIncidencia.currentState?.validate() != true ||
        enviando) {
      return;
    }

    setState(() {
      enviando = true;
      error = null;
    });
    final motivo = await widget.onEnviar(
      bicicleteroId: bicicletero.id,
      tipo: tipoSeleccionado,
      descripcion: descripcion,
      bicicletaId: bicicletaSeleccionada?.id,
      fotos: List<String>.unmodifiable(fotos),
    );

    if (!mounted) {
      return;
    }
    if (motivo == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        enviando = false;
        error = motivo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registrar incidencia',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.borrador == null
                  ? 'Completa el reporte para que el equipo pueda gestionarlo.'
                  : 'Recuperamos el reporte que estabas completando cuando '
                      'se cerró la app.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColoresUbb.textoSecundario,
                  ),
            ),
            const SizedBox(height: 12),
            Form(
              key: formKeyIncidencia,
              child: FormularioIncidencia(
                cargando: false,
                enviando: enviando,
                bicicleteros: widget.bicicleteros,
                bicicletas: widget.bicicletas,
                bicicleteroSeleccionado: bicicleteroSeleccionado,
                bicicletaSeleccionada: bicicletaSeleccionada,
                tipoSeleccionado: tipoSeleccionado,
                descripcionController: descripcionController,
                fotos: fotos,
                onCamara: () => _seleccionarFoto(ImageSource.camera),
                onGaleria: () => _seleccionarFoto(ImageSource.gallery),
                onQuitarFoto: (indice) =>
                    setState(() => fotos.removeAt(indice)),
                permitirBicicletaPropia: widget.permitirBicicletaPropia,
                onBicicletero: (valor) =>
                    setState(() => bicicleteroSeleccionado = valor),
                onBicicleta: (valor) =>
                    setState(() => bicicletaSeleccionada = valor),
                onTipo: (valor) => setState(() => tipoSeleccionado = valor),
                onEnviar: _enviar,
                error: error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
