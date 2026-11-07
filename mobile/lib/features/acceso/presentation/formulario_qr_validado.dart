import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:ubbike/features/acceso/presentation/botones_decision_movimiento.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/shared/widgets/selector_foto.dart';
import 'package:ubbike/shared/utilidades/revision_ortografica.dart';

String? _validarComentarioQrGuardia(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.length > 600) {
    return 'Máximo 600 caracteres.';
  }
  return null;
}

class FormularioQrValidado extends StatelessWidget {
  const FormularioQrValidado({
    super.key,
    required this.claveFormulario,
    required this.qr,
    required this.controladorComentario,
    required this.onConfirmar,
    required this.onDenegar,
    required this.onLeerOtro,
    this.procesando = false,
  });

  final GlobalKey<FormState> claveFormulario;
  final QrValidadoApp qr;
  final TextEditingController controladorComentario;
  final VoidCallback onConfirmar;
  final VoidCallback onDenegar;
  final VoidCallback onLeerOtro;
  final bool procesando;

  @override
  Widget build(BuildContext context) {
    final esIngreso = qr.tipo == 'INGRESO';
    final color = esIngreso ? ColoresUbb.exito : ColoresUbb.azulApp;
    final accion = esIngreso ? 'Ingreso' : 'Retiro';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: claveFormulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      esIngreso ? Icons.login : Icons.logout,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QR válido',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        Text(
                          'Autorizar ${accion.toLowerCase()}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: ColoresUbb.azulNoche,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  ChipEstado(texto: accion, color: color),
                ],
              ),
              const SizedBox(height: 14),
              const _TituloFormularioQr(
                icono: Icons.person_outline,
                texto: 'Información del usuario',
              ),
              const SizedBox(height: 10),
              _CampoLecturaQr(
                label: 'Nombre',
                valor: qr.usuarioNombre,
              ),
              const SizedBox(height: 10),
              _CampoLecturaQr(
                label: 'Correo',
                valor: qr.usuarioCorreo,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CampoLecturaQr(
                      label: 'RUT',
                      valor: qr.usuarioRut ?? 'Sin RUT',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CampoLecturaQr(
                      label: 'Bicicletero',
                      valor: qr.bicicleteroNombre ?? 'Bicicletero de tu turno',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _TituloFormularioQr(
                icono: Icons.pedal_bike_outlined,
                texto: 'Datos de bicicleta',
              ),
              const SizedBox(height: 10),
              _CampoLecturaQr(
                label: 'Descripción',
                valor: qr.bicicletaDescripcion,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CampoLecturaQr(
                      label: 'Marca',
                      valor: textoNoVacio(qr.bicicletaMarca, 'Sin marca'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CampoLecturaQr(
                      label: 'Modelo',
                      valor: textoNoVacio(qr.bicicletaModelo, 'Sin modelo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CampoLecturaQr(
                      label: 'Color',
                      valor: textoNoVacio(qr.bicicletaColor, 'Sin color'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CampoLecturaQr(
                      label: 'Aro',
                      valor: textoNoVacio(qr.bicicletaAro, 'Sin aro'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _CampoLecturaQr(
                label: 'Número de serie',
                valor: textoNoVacio(qr.bicicletaNumeroSerie, 'Sin serie'),
              ),
              const SizedBox(height: 12),
              SelectorFoto(
                fotoDataUrl: qr.bicicletaFotoUrl,
                onCamara: () {},
                onGaleria: () {},
                onQuitar: null,
                mostrarAcciones: false,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: controladorComentario,
                spellCheckConfiguration: revisionOrtografica(),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Comentario opcional del guardia',
                  hintText: 'Ej: Usuario posee U-Lock',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                ),
                validator: _validarComentarioQrGuardia,
              ),
              const SizedBox(height: 16),
              BotonesDecisionMovimiento(
                esIngreso: esIngreso,
                procesando: procesando,
                habilitado: true,
                onConfirmar: onConfirmar,
                onRechazar: onDenegar,
                textoSecundario: 'Escanear nuevamente',
                iconoSecundario: Icons.qr_code_scanner_outlined,
                onSecundario: onLeerOtro,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String textoNoVacio(String? valor, String respaldo) {
    final texto = valor?.trim();
    return texto == null || texto.isEmpty ? respaldo : texto;
  }
}

class _TituloFormularioQr extends StatelessWidget {
  const _TituloFormularioQr({
    required this.icono,
    required this.texto,
  });

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, color: ColoresUbb.azulApp, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            texto,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: ColoresUbb.azulNoche,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

class _CampoLecturaQr extends StatelessWidget {
  const _CampoLecturaQr({
    required this.label,
    required this.valor,
  });

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('$label-$valor'),
      initialValue: valor,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
    );
  }
}
