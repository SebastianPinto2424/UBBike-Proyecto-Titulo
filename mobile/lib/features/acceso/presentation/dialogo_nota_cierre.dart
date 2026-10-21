import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/widgets/botones_accion.dart';
import 'package:ubbike/shared/widgets/dialogo_accion.dart';

class DialogoNotaCierre extends StatefulWidget {
  const DialogoNotaCierre({super.key, required this.estado});

  final String estado;

  @override
  State<DialogoNotaCierre> createState() => _DialogoNotaCierreState();
}

class _DialogoNotaCierreState extends State<DialogoNotaCierre> {
  final formKeyNotaCierre = GlobalKey<FormState>();
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (formKeyNotaCierre.currentState?.validate() != true) {
      return;
    }

    Navigator.of(context).pop(controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final resuelta = widget.estado == 'RESUELTA';

    return DialogoAccion(
      icono: resuelta ? Icons.check_circle_outline : Icons.cancel_outlined,
      colorIcono: resuelta ? ColoresUbb.azulApp : ColoresUbb.rojoInstitucional,
      titulo: resuelta
          ? 'Marcar solicitud como resuelta'
          : 'Cerrar solicitud sin resolver',
      contenido: Form(
        key: formKeyNotaCierre,
        child: TextFormField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Motivo del cierre',
            hintText: 'Ej: El guardia no respondió, se cerró desde central.',
            alignLabelWithHint: true,
          ),
          validator: (valor) => (valor == null || valor.trim().isEmpty)
              ? 'Escribe un motivo para cerrar la solicitud.'
              : null,
        ),
      ),
      acciones: BotonesAccion.confirmacion(
        destructiva: !resuelta,
        textoConfirmar: 'Confirmar',
        onCancelar: () => Navigator.of(context).pop(),
        onConfirmar: _confirmar,
      ),
    );
  }
}
