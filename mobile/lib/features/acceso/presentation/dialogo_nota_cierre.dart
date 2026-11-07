import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/widgets/botones_accion.dart';
import 'package:ubbike/shared/widgets/dialogo_accion.dart';
import 'package:ubbike/shared/utilidades/revision_ortografica.dart';

class DialogoNotaCierre extends StatefulWidget {
  const DialogoNotaCierre({super.key});

  @override
  State<DialogoNotaCierre> createState() => _DialogoNotaCierreState();
}

class _DialogoNotaCierreState extends State<DialogoNotaCierre> {
  final claveFormularioNotaCierre = GlobalKey<FormState>();
  late final TextEditingController controlador;

  @override
  void initState() {
    super.initState();
    controlador = TextEditingController();
  }

  @override
  void dispose() {
    controlador.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (claveFormularioNotaCierre.currentState?.validate() != true) {
      return;
    }

    Navigator.of(context).pop(controlador.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return DialogoAccion(
      icono: Icons.cancel_outlined,
      colorIcono: ColoresUbb.rojoInstitucional,
      titulo: 'Cerrar solicitud sin resolver',
      contenido: Form(
        key: claveFormularioNotaCierre,
        child: TextFormField(
          controller: controlador,
          spellCheckConfiguration: revisionOrtografica(),
          textCapitalization: TextCapitalization.sentences,
          minLines: 3,
          maxLines: 5,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Motivo del cierre',
            hintText: 'Ej: Solicitud duplicada o el solicitante no responde.',
            alignLabelWithHint: true,
          ),
          validator: validarNotaCierre,
        ),
      ),
      acciones: BotonesAccion.confirmacion(
        destructiva: true,
        textoConfirmar: 'Confirmar',
        onCancelar: () => Navigator.of(context).pop(),
        onConfirmar: _confirmar,
      ),
    );
  }
}

String? validarNotaCierre(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Escribe un motivo para cerrar la solicitud.';
  }
  if (texto.length < 3) {
    return 'Debe tener al menos 3 caracteres.';
  }
  if (texto.length > 600) {
    return 'Máximo 600 caracteres.';
  }
  return null;
}
