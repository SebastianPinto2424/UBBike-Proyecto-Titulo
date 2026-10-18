import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/incidencia_modelos.dart';

class DialogoRespuestaGestion extends StatefulWidget {
  const DialogoRespuestaGestion({
    super.key,
    required this.incidencia,
    required this.estado,
    required this.respuestaInicial,
  });

  final IncidenciaApp incidencia;
  final String estado;
  final String respuestaInicial;

  @override
  State<DialogoRespuestaGestion> createState() =>
      _DialogoRespuestaGestionState();
}

class _DialogoRespuestaGestionState extends State<DialogoRespuestaGestion> {
  final formKeyRespuestaGestion = GlobalKey<FormState>();
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.respuestaInicial);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _guardar() {
    if (formKeyRespuestaGestion.currentState?.validate() != true) {
      return;
    }

    final texto = controller.text.trim();
    Navigator.of(context).pop(texto);
  }

  @override
  Widget build(BuildContext context) {
    final descartar = widget.estado == 'DESCARTADA';
    final color = descartar ? ColoresUbb.rojoInstitucional : ColoresUbb.azulApp;
    final incidencia = widget.incidencia;

    return AlertDialog(
      scrollable: true,
      icon: Icon(
        descartar ? Icons.block_outlined : Icons.check_circle_outline,
        color: color,
        size: 44,
      ),
      title: Text(
        descartar ? 'Descartar incidencia' : 'Marcar incidencia como resuelta',
        textAlign: TextAlign.center,
      ),
      content: Form(
        key: formKeyRespuestaGestion,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: controller,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Respuesta de cierre',
                hintText: 'Explica la resolución o el motivo del cierre.',
                alignLabelWithHint: true,
              ),
              validator: _validarRespuestaGestionIncidencia,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 16,
                  color: ColoresUbb.textoSecundario,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Esta respuesta le llegará a ${incidencia.reportadaPorUsuario.nombre} por correo y notificación.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColoresUbb.textoSecundario,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColoresUbb.azulApp,
                  side: const BorderSide(color: ColoresUbb.azulApp),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.of(context).pop(null),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Cancelar'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _guardar,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(descartar ? 'Descartar' : 'Marcar resuelta'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String? _validarRespuestaGestionIncidencia(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa una respuesta de cierre.';
  }
  if (texto.length < 8) {
    return 'Debe explicar el cierre con al menos 8 caracteres.';
  }
  if (texto.length > 1000) {
    return 'Máximo 1000 caracteres.';
  }
  return null;
}
