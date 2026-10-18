import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/estilos_formulario.dart';

class SheetSolicitarAtencion extends StatefulWidget {
  const SheetSolicitarAtencion({
    super.key,
    required this.bicicleteros,
    required this.onEnviar,
  });

  final List<BicicleteroApp> bicicleteros;

  final Future<String?> Function(String bicicleteroId, String mensaje) onEnviar;

  @override
  State<SheetSolicitarAtencion> createState() => _SheetSolicitarAtencionState();
}

class _SheetSolicitarAtencionState extends State<SheetSolicitarAtencion> {
  final formKeySolicitarAtencion = GlobalKey<FormState>();
  final mensajeController = TextEditingController();
  BicicleteroApp? seleccionado;
  bool enviando = false;
  String? error;

  @override
  void initState() {
    super.initState();
    seleccionado =
        widget.bicicleteros.isEmpty ? null : widget.bicicleteros.first;
  }

  @override
  void dispose() {
    mensajeController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final bicicletero = seleccionado;
    if (bicicletero == null ||
        formKeySolicitarAtencion.currentState?.validate() != true ||
        enviando) {
      return;
    }

    setState(() {
      enviando = true;
      error = null;
    });
    final motivo =
        await widget.onEnviar(bicicletero.id, mensajeController.text.trim());

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
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: formKeySolicitarAtencion,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Solicitar atención',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  return DropdownAnclado<BicicleteroApp>(
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    menuMaxHeight: 300,
                    value: seleccionado,
                    decoration: decoracionCampoFormularioBicicleta(
                      labelText: 'Bicicletero',
                    ),
                    dropdownColor: Colors.white,
                    items: widget.bicicleteros
                        .map(
                          (bicicletero) => DropdownMenuItem(
                            value: bicicletero,
                            child: Text(
                              bicicletero.nombre,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: enviando
                        ? null
                        : (valor) => setState(() => seleccionado = valor),
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: ColoresUbb.azulApp.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextFormField(
                  controller: mensajeController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje (opcional)',
                    hintText: 'Ej: Necesito retirar mi bicicleta.',
                    alignLabelWithHint: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  validator: _validarMensajeSolicitudGuardia,
                ),
              ),
              const SizedBox(height: 20),
              if (error != null) ...[
                ErrorFormulario(mensaje: error!),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: ColoresUbb.azulApp,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: seleccionado == null || enviando ? null : _enviar,
                icon: enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  enviando ? 'Enviando...' : 'Solicitar atención',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _validarMensajeSolicitudGuardia(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.length > 600) {
    return 'Máximo 600 caracteres.';
  }
  return null;
}
