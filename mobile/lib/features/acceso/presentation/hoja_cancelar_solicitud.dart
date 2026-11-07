import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/acceso/presentation/solicitud_guardia_widgets.dart';
import 'package:ubbike/shared/modelos/solicitud_guardia_modelos.dart';
import 'package:ubbike/shared/widgets/botones_accion.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/estilos_formulario.dart';
import 'package:ubbike/shared/utilidades/revision_ortografica.dart';

const motivosCancelacionSolicitud = [
  'Ya lo resolví',
  'Me equivoqué de bicicletero',
  'Ya no necesito ayuda',
];

const otroMotivoCancelacion = 'Otro motivo';

class HojaCancelarSolicitud extends StatefulWidget {
  const HojaCancelarSolicitud({
    super.key,
    required this.solicitud,
    required this.onCancelar,
  });

  final ValueListenable<SolicitudGuardiaApp> solicitud;

  final Future<String?> Function(String motivo) onCancelar;

  @override
  State<HojaCancelarSolicitud> createState() => _HojaCancelarSolicitudState();
}

class _HojaCancelarSolicitudState extends State<HojaCancelarSolicitud> {
  final claveFormularioCancelarSolicitud = GlobalKey<FormState>();
  final controladorDetalle = TextEditingController();
  String? motivo;
  bool enviando = false;
  String? error;

  bool get otroMotivo => motivo == otroMotivoCancelacion;

  @override
  void dispose() {
    controladorDetalle.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final elegido = motivo;
    if (claveFormularioCancelarSolicitud.currentState?.validate() != true ||
        elegido == null ||
        enviando) {
      return;
    }

    setState(() {
      enviando = true;
      error = null;
    });
    final resultado = await widget.onCancelar(
      otroMotivo ? controladorDetalle.text.trim() : elegido,
    );

    if (!mounted) {
      return;
    }
    if (resultado == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        enviando = false;
        error = resultado;
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
        child: ValueListenableBuilder<SolicitudGuardiaApp>(
          valueListenable: widget.solicitud,
          builder: (context, solicitud, _) {
            final cerrada = !enviando &&
                (solicitud.estado == 'RESUELTA' ||
                    solicitud.estado == 'CANCELADA');

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cancelar solicitud',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${solicitud.bicicletero.nombre} · ${etiquetaEstadoSolicitud(solicitud.estado)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColoresUbb.textoSecundario,
                      ),
                ),
                const SizedBox(height: 16),
                if (cerrada)
                  ..._contenidoCerrada(solicitud)
                else
                  _formulario(solicitud),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _contenidoCerrada(SolicitudGuardiaApp solicitud) {
    return [
      _AvisoCancelacion(
        icono: Icons.check_circle_outline,
        texto: textoSolicitudYaCerrada(solicitud),
      ),
      const SizedBox(height: 20),
      BotonAccion(
        accion: AccionBoton(
          texto: 'Entendido',
          color: ColoresUbb.azulApp,
          icono: Icons.check,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    ];
  }

  Widget _formulario(SolicitudGuardiaApp solicitud) {
    final enCamino = solicitud.estado == 'EN_CAMINO';

    return Form(
      key: claveFormularioCancelarSolicitud,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AvisoCancelacion(
            icono: enCamino ? Icons.directions_walk : Icons.info_outline,
            texto: enCamino
                ? 'El guardia va en camino. Le avisaremos que ya no es necesario ir.'
                : 'Tu solicitud se cerrará y el guardia ya no la verá pendiente.',
          ),
          const SizedBox(height: 16),
          FormField<String>(
            initialValue: motivo,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (valor) => valor == null ? 'Elige un motivo.' : null,
            builder: (campo) => DropdownAnclado<String>(
              value: campo.value,
              decoration: decoracionCampoFormularioBicicleta(
                labelText: 'Motivo',
                errorText: campo.errorText,
              ),
              items: [
                for (final opcion in [
                  ...motivosCancelacionSolicitud,
                  otroMotivoCancelacion,
                ])
                  DropdownMenuItem(value: opcion, child: Text(opcion)),
              ],
              onChanged: enviando
                  ? null
                  : (valor) {
                      campo.didChange(valor);
                      setState(() {
                        motivo = valor;
                        error = null;
                      });
                    },
            ),
          ),
          if (otroMotivo) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: ColoresUbb.azulApp.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextFormField(
                controller: controladorDetalle,
                spellCheckConfiguration: revisionOrtografica(),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                enabled: !enviando,
                decoration: const InputDecoration(
                  labelText: 'Cuéntanos el motivo',
                  alignLabelWithHint: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                validator: validarDetalleCancelacion,
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (error != null) ...[
            ErrorFormulario(mensaje: error!),
            const SizedBox(height: 12),
          ],
          BotonAccion(
            accion: AccionBoton(
              texto: 'Cancelar solicitud',
              color: ColoresUbb.rojoInstitucional,
              icono: Icons.block,
              cargando: enviando,
              onPressed: enviando ? null : _enviar,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoCancelacion extends StatelessWidget {
  const _AvisoCancelacion({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ColoresUbb.azulApp.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresUbb.azulApp.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icono, size: 20, color: ColoresUbb.azulApp),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColoresUbb.textoPrincipal,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String textoSolicitudYaCerrada(SolicitudGuardiaApp solicitud) {
  if (solicitud.estado == 'RESUELTA') {
    return 'El guardia ya resolvió esta solicitud. No es necesario cancelarla.';
  }
  if (solicitud.cerradaPor == 'CENTRAL') {
    return 'Central cerró esta solicitud. No es necesario cancelarla.';
  }
  return 'Esta solicitud ya está cerrada.';
}

String? validarDetalleCancelacion(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Escribe el motivo.';
  }
  if (texto.length < 3) {
    return 'Debe tener al menos 3 caracteres.';
  }
  if (texto.length > 200) {
    return 'Máximo 200 caracteres.';
  }
  return null;
}
