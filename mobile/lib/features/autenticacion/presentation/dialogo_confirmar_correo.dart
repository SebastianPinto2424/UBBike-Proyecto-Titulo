import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/widgets/estilos_formulario_autenticacion.dart';

const _esperaEntreReenvios = Duration(seconds: 60);

class DialogoConfirmarCorreo extends StatefulWidget {
  const DialogoConfirmarCorreo({
    super.key,
    required this.correo,
    required this.onReenviar,
  });

  final String correo;
  final Future<void> Function() onReenviar;

  @override
  State<DialogoConfirmarCorreo> createState() => _DialogoConfirmarCorreoState();
}

class _DialogoConfirmarCorreoState extends State<DialogoConfirmarCorreo> {
  Timer? temporizador;
  int segundosRestantes = 0;
  bool enviando = false;
  String? aviso;
  bool avisoEsError = false;

  @override
  void dispose() {
    temporizador?.cancel();
    super.dispose();
  }

  void _iniciarEspera() {
    temporizador?.cancel();
    segundosRestantes = _esperaEntreReenvios.inSeconds;
    temporizador = Timer.periodic(const Duration(seconds: 1), (reloj) {
      if (!mounted) {
        reloj.cancel();
        return;
      }
      setState(() => segundosRestantes--);
      if (segundosRestantes <= 0) {
        reloj.cancel();
      }
    });
  }

  Future<void> _reenviar() async {
    setState(() {
      enviando = true;
      aviso = null;
    });
    try {
      await widget.onReenviar();
      if (mounted) {
        setState(() {
          aviso = 'Te enviamos un enlace nuevo.';
          avisoEsError = false;
          _iniciarEspera();
        });
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        setState(() {
          aviso = error.mensaje;
          avisoEsError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          aviso = mensajeSinConexion;
          avisoEsError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => enviando = false);
      }
    }
  }

  String get _textoReenvio {
    if (enviando) {
      return 'Enviando…';
    }
    return segundosRestantes > 0
        ? 'Reenviar correo ($segundosRestantes s)'
        : 'Reenviar correo';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AlertDialog(
      backgroundColor: ColoresUbb.fondo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ColoresUbb.exito.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              color: ColoresUbb.exito,
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Confirma tu correo',
            textAlign: TextAlign.center,
            style: tema.textTheme.titleLarge?.copyWith(
              color: ColoresUbb.textoPrincipal,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Aún no confirmas '),
                TextSpan(
                  text: widget.correo,
                  style: const TextStyle(
                    color: ColoresUbb.textoPrincipal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(
                  text: '. Abre el enlace que te enviamos o pide uno nuevo.',
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyMedium?.copyWith(
              color: ColoresUbb.textoSecundario,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¿No llega? Revisa la carpeta de spam o correo no deseado.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall?.copyWith(
              color: ColoresUbb.textoSecundario,
            ),
          ),
          if (aviso != null) ...[
            const SizedBox(height: 10),
            Text(
              aviso!,
              key: const Key('aviso-reenvio'),
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall?.copyWith(
                color: avisoEsError
                    ? ColoresUbb.rojoInstitucional
                    : ColoresUbb.exito,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: estiloBotonAutenticacion(),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const Key('reenviar-correo'),
            onPressed: enviando || segundosRestantes > 0 ? null : _reenviar,
            child: Text(_textoReenvio),
          ),
        ],
      ),
    );
  }
}
