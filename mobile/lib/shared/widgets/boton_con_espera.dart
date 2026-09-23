import 'dart:async';

import 'package:flutter/material.dart';

String formatearEspera(int segundos) {
  if (segundos < 60) {
    return '${segundos}s';
  }
  final minutos = segundos ~/ 60;
  final resto = segundos % 60;
  return '$minutos:${resto.toString().padLeft(2, '0')}';
}

class BotonConEspera extends StatefulWidget {
  const BotonConEspera({
    super.key,
    required this.segundosRestantes,
    required this.etiquetaLista,
    required this.prefijoEspera,
    required this.icono,
    required this.onPresionar,
    this.alTerminarEspera,
    this.ahora,
  });

  final int? segundosRestantes;

  final String etiquetaLista;

  final String prefijoEspera;

  final IconData icono;
  final VoidCallback? onPresionar;

  final VoidCallback? alTerminarEspera;

  final DateTime Function()? ahora;

  @override
  State<BotonConEspera> createState() => _BotonConEsperaState();
}

class _BotonConEsperaState extends State<BotonConEspera> {
  Timer? _tic;
  late DateTime _ancla;
  late int _base;
  int _restantes = 0;
  bool _avisado = false;

  @override
  void initState() {
    super.initState();
    _reiniciar();
  }

  @override
  void didUpdateWidget(covariant BotonConEspera anterior) {
    super.didUpdateWidget(anterior);

    if (anterior.segundosRestantes != widget.segundosRestantes) {
      _reiniciar();
    }
  }

  @override
  void dispose() {
    _tic?.cancel();
    super.dispose();
  }

  DateTime _reloj() => (widget.ahora ?? DateTime.now)();

  void _reiniciar() {
    _tic?.cancel();
    _base = widget.segundosRestantes ?? 0;
    _ancla = _reloj();
    _restantes = _base;
    _avisado = _base <= 0;

    if (_base > 0) {
      _tic = Timer.periodic(const Duration(seconds: 1), (_) => _actualizar());
    }
  }

  void _actualizar() {
    if (!mounted) return;

    final transcurridos = _reloj().difference(_ancla).inSeconds;
    final nuevo = (_base - transcurridos).clamp(0, _base);
    if (nuevo == _restantes) return;

    setState(() => _restantes = nuevo);

    if (nuevo == 0 && !_avisado) {
      _avisado = true;
      _tic?.cancel();
      widget.alTerminarEspera?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final esperando = _restantes > 0;

    return OutlinedButton.icon(
      onPressed: esperando ? null : widget.onPresionar,
      icon: Icon(widget.icono),
      label: Text(esperando
          ? '${widget.prefijoEspera} ${formatearEspera(_restantes)}'
          : widget.etiquetaLista),
    );
  }
}
