import 'package:flutter/material.dart';
import 'package:ubbike/shared/utils/opciones_bicicleta.dart';
import 'package:ubbike/shared/widgets/estilos_formulario.dart';

class CampoColorBicicleta extends StatefulWidget {
  const CampoColorBicicleta({
    super.key,
    required this.valorInicial,
    required this.habilitado,
    required this.onChanged,
    this.helperText,
    this.validator,
  });

  final String valorInicial;
  final bool habilitado;
  final ValueChanged<String> onChanged;
  final String? helperText;
  final FormFieldValidator<String>? validator;

  @override
  State<CampoColorBicicleta> createState() => _CampoColorBicicletaState();
}

class _CampoColorBicicletaState extends State<CampoColorBicicleta> {
  FocusNode? _focusNode;

  @override
  void dispose() {
    _focusNode?.removeListener(_actualizarFoco);
    super.dispose();
  }

  void _sincronizarFocusNode(FocusNode focusNode) {
    if (_focusNode == focusNode) {
      return;
    }
    _focusNode?.removeListener(_actualizarFoco);
    _focusNode = focusNode..addListener(_actualizarFoco);
  }

  void _actualizarFoco() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.valorInicial),
      displayStringForOption: (opcion) => opcion,
      optionsBuilder: (texto) => sugerirColoresBicicleta(texto.text),
      onSelected: widget.onChanged,
      fieldViewBuilder: (
        context,
        controller,
        focusNode,
        onFieldSubmitted,
      ) {
        _sincronizarFocusNode(focusNode);

        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.habilitado,
          decoration: decoracionCampoFormularioBicicleta(
            labelText: 'Color',
            helperText: focusNode.hasFocus ? widget.helperText : null,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          onChanged: widget.onChanged,
          validator: widget.validator ?? validarColorBicicleta,
        );
      },
    );
  }
}
