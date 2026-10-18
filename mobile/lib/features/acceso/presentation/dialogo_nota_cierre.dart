import 'package:flutter/material.dart';

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
    return AlertDialog(
      title: Text(
        widget.estado == 'RESUELTA'
            ? 'Marcar solicitud como resuelta'
            : 'Cerrar solicitud sin resolver',
      ),
      content: Form(
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _confirmar,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
