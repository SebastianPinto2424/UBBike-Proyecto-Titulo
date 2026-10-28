import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/widgets/botones_accion.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/utilidades/revision_ortografica.dart';

typedef MotivoRechazo = ({IconData icono, String titulo, String detalle});

const motivosRechazo = <MotivoRechazo>[
  (
    icono: Icons.pedal_bike_outlined,
    titulo: 'La bicicleta no coincide',
    detalle: 'No es la bicicleta registrada por el titular.',
  ),
  (
    icono: Icons.badge_outlined,
    titulo: 'Los datos no coinciden con el titular',
    detalle: 'La persona o sus datos no corresponden al titular.',
  ),
];

class HojaDenegacion extends StatefulWidget {
  const HojaDenegacion({
    super.key,
    required this.esIngreso,
    required this.onConfirmar,
  });

  final bool esIngreso;
  final Future<String?> Function(String motivo) onConfirmar;

  @override
  State<HojaDenegacion> createState() => _HojaDenegacionState();
}

class _HojaDenegacionState extends State<HojaDenegacion> {
  final formKeyDenegacion = GlobalKey<FormState>();
  final detalleController = TextEditingController();
  MotivoRechazo? seleccionado;
  bool enviando = false;
  String? error;

  @override
  void dispose() {
    detalleController.dispose();
    super.dispose();
  }

  String _motivoParaEnviar(MotivoRechazo motivo) {
    final detalle = detalleController.text.trim();
    return detalle.isEmpty ? motivo.titulo : '${motivo.titulo}. $detalle';
  }

  Future<void> _enviar() async {
    final motivo = seleccionado;
    if (enviando) {
      return;
    }
    if (motivo == null) {
      setState(() => error = 'Selecciona el motivo del rechazo.');
      return;
    }
    if (formKeyDenegacion.currentState?.validate() != true) {
      return;
    }
    setState(() {
      enviando = true;
      error = null;
    });
    final rechazo = await widget.onConfirmar(_motivoParaEnviar(motivo));
    if (!mounted) {
      return;
    }
    if (rechazo == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        enviando = false;
        error = rechazo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final operacion = widget.esIngreso ? 'ingreso' : 'retiro';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: formKeyDenegacion,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Rechazar $operacion',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Selecciona el motivo. La persona lo verá en su pantalla '
                'y en el correo del movimiento.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColoresUbb.textoSecundario,
                    ),
              ),
              const SizedBox(height: 14),
              for (final motivo in motivosRechazo) ...[
                _OpcionMotivoRechazo(
                  motivo: motivo,
                  seleccionado: seleccionado == motivo,
                  onTap: enviando
                      ? null
                      : () => setState(() {
                            seleccionado = motivo;
                            error = null;
                          }),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 4),
              TextFormField(
                controller: detalleController,
                spellCheckConfiguration: revisionOrtografica(),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                enabled: !enviando,
                decoration: const InputDecoration(
                  labelText: 'Detalle (opcional)',
                  hintText: 'Ej: la bicicleta es de otro color',
                  alignLabelWithHint: true,
                ),
                validator: _validarDetalleRechazo,
              ),
              const SizedBox(height: 16),
              if (error != null) ...[
                ErrorFormulario(mensaje: error!),
                const SizedBox(height: 12),
              ],
              BotonesAccion.confirmacion(
                destructiva: true,
                textoConfirmar: 'Rechazar',
                iconoConfirmar: Icons.block,
                iconoCancelar: Icons.close,
                cargando: enviando,
                onConfirmar: enviando ? null : _enviar,
                onCancelar: enviando ? null : () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionMotivoRechazo extends StatelessWidget {
  const _OpcionMotivoRechazo({
    required this.motivo,
    required this.seleccionado,
    required this.onTap,
  });

  final MotivoRechazo motivo;
  final bool seleccionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const rojo = ColoresUbb.rojoInstitucional;

    return Semantics(
      button: true,
      selected: seleccionado,
      child: Material(
        color: seleccionado ? rojo.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: seleccionado ? rojo : ColoresUbb.borde,
                width: seleccionado ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (seleccionado ? rojo : ColoresUbb.azulApp)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    motivo.icono,
                    color: seleccionado ? rojo : ColoresUbb.azulApp,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        motivo.titulo,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: ColoresUbb.azulNoche,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        motivo.detalle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ColoresUbb.textoSecundario,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  seleccionado
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: seleccionado ? rojo : ColoresUbb.bordeFuerte,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _validarDetalleRechazo(String? valor) {
  if ((valor?.trim().length ?? 0) > 500) {
    return 'Máximo 500 caracteres.';
  }
  return null;
}
