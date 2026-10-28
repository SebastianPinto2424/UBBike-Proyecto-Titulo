import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ubbike/features/acceso/presentation/campos_gestion_manual.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/features/acceso/presentation/gestion_manual_widgets.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/utilidades/opciones_bicicleta.dart';
import 'package:ubbike/features/acceso/presentation/validaciones_gestion_manual.dart';
import 'package:ubbike/shared/widgets/campo_color_bicicleta.dart';
import 'package:ubbike/shared/widgets/selector_foto.dart';
import 'package:ubbike/shared/utilidades/revision_ortografica.dart';

class SeccionBicicletaManual extends StatelessWidget {
  const SeccionBicicletaManual({
    super.key,
    required this.campos,
    required this.operacion,
    required this.bicicletaSeleccionadaId,
    required this.busquedaRealizada,
    required this.bicicletasRegistradas,
    required this.fotoNueva,
    required this.errorFoto,
    required this.onSeleccionarBicicleta,
    required this.onUsarNoRegistrada,
    required this.onCampoEditado,
    required this.onElegirFoto,
    required this.onQuitarFoto,
  });

  final CamposGestionManual campos;
  final String operacion;
  final String? bicicletaSeleccionadaId;
  final bool busquedaRealizada;
  final List<BicicletaApp> bicicletasRegistradas;
  final String? fotoNueva;
  final String? errorFoto;
  final ValueChanged<String?> onSeleccionarBicicleta;
  final VoidCallback onUsarNoRegistrada;
  final VoidCallback onCampoEditado;
  final ValueChanged<ImageSource> onElegirFoto;
  final VoidCallback onQuitarFoto;

  @override
  Widget build(BuildContext context) {
    final bicicletaSeleccionada = bicicletasRegistradas
        .where((bicicleta) => bicicleta.id == bicicletaSeleccionadaId)
        .firstOrNull;
    final creandoBicicletaNueva = bicicletaSeleccionadaId == null;
    final mostrandoBicicletaRegistrada =
        bicicletasRegistradas.isNotEmpty && bicicletaSeleccionadaId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Datos de bicicleta',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: ColoresUbb.azulNoche,
              ),
        ),
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (bicicletaSeleccionadaId != null)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ChipEstado(
                    texto: 'Bicicleta registrada',
                    color: ColoresUbb.azulApp,
                  ),
                ),
              )
            else if (busquedaRealizada)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ChipEstado(
                    texto: 'Bicicleta no registrada',
                    color: ColoresUbb.azulApp,
                  ),
                ),
              ),
            if (mostrandoBicicletaRegistrada) ...[
              if (bicicletasRegistradas.length == 1 &&
                  bicicletaSeleccionada != null)
                DetalleBicicletaRegistrada(
                  bicicleta: bicicletaSeleccionada,
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    return DropdownAnclado<String>(
                      key: ValueKey(
                        bicicletaSeleccionadaId ?? 'sin-bici',
                      ),
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      menuMaxHeight: 300,
                      value: bicicletaSeleccionadaId,
                      decoration: decoracionCampoGestionManual(
                        labelText: 'Bicicleta registrada',
                      ),
                      items: bicicletasRegistradas
                          .map(
                            (bicicleta) => DropdownMenuItem(
                              value: bicicleta.id,
                              child: Text(
                                _resumenBicicleta(bicicleta),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (valor) => onSeleccionarBicicleta(valor),
                    );
                  },
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: UnconstrainedBox(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ColoresUbb.azulApp,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: onUsarNoRegistrada,
                    icon: const Icon(
                      Icons.pedal_bike_outlined,
                      size: 16,
                    ),
                    label: const Text('Registrar otra bicicleta'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextFormField(
              controller: campos.descripcion,
              spellCheckConfiguration: revisionOrtografica(),
              textCapitalization: TextCapitalization.sentences,
              focusNode: campos.focoDescripcion,
              readOnly:
                  bicicletaSeleccionadaId != null && operacion == 'RETIRO',
              onChanged: (_) => onCampoEditado(),
              decoration: decoracionCampoGestionManual(
                labelText: 'Descripción',
                helperText: ayudaSiActivo(
                  campos.focoDescripcion,
                  'Nombre breve para reconocer la bicicleta.',
                ),
              ),
              validator: (valor) => creandoBicicletaNueva
                  ? validarDescripcionBicicleta(valor)
                  : validarDescripcionBicicletaManual(
                      valor,
                      false,
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: campos.marca,
                    focusNode: campos.focoMarca,
                    readOnly: bicicletaSeleccionadaId != null &&
                        operacion == 'RETIRO',
                    onChanged: (_) => onCampoEditado(),
                    decoration: decoracionCampoGestionManual(
                      labelText: 'Marca',
                      helperText: ayudaSiActivo(
                        campos.focoMarca,
                        'Usa la marca visible o registrada.',
                      ),
                    ),
                    validator: (valor) => validarCampoRequeridoConFormato(
                      valor,
                      requerido: creandoBicicletaNueva,
                      mensajeRequerido: 'Ingresa la marca.',
                      validarFormato: validarMarcaBicicleta,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: campos.modelo,
                    focusNode: campos.focoModelo,
                    readOnly: bicicletaSeleccionadaId != null &&
                        operacion == 'RETIRO',
                    onChanged: (_) => onCampoEditado(),
                    decoration: decoracionCampoGestionManual(
                      labelText: 'Modelo',
                      helperText: ayudaSiActivo(
                        campos.focoModelo,
                        'Usa el modelo visible o una referencia breve.',
                      ),
                    ),
                    validator: (valor) => validarCampoRequeridoConFormato(
                      valor,
                      requerido: creandoBicicletaNueva,
                      mensajeRequerido: 'Ingresa el modelo.',
                      validarFormato: validarModeloBicicleta,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CampoColorBicicleta(
                    key: ValueKey(
                      'color-manual-${bicicletaSeleccionadaId ?? 'nuevo'}',
                    ),
                    valorInicial: campos.color.text,
                    habilitado: !(bicicletaSeleccionadaId != null &&
                        operacion == 'RETIRO'),
                    helperText: 'Color principal o combinacion simple.',
                    onChanged: (valor) {
                      campos.color.text = valor;
                      onCampoEditado();
                    },
                    validator: (valor) => validarCampoRequeridoConFormato(
                      valor,
                      requerido: creandoBicicletaNueva,
                      mensajeRequerido: 'Ingresa el color.',
                      validarFormato: validarColorBicicleta,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FormField<String>(
                    key: ValueKey(
                      'aro-manual-${bicicletaSeleccionadaId ?? 'nuevo'}-${campos.aro.text}',
                    ),
                    initialValue: normalizarAroBicicleta(
                          campos.aro.text,
                        ) ??
                        '',
                    validator: (valor) => validarAroGestionManual(
                      valor,
                      requerido: creandoBicicletaNueva,
                    ),
                    builder: (field) {
                      final bloqueado = bicicletaSeleccionadaId != null &&
                          operacion == 'RETIRO';
                      final valor = field.value ?? '';

                      return DropdownAnclado<String>(
                        value: valor,
                        decoration: decoracionCampoGestionManual(
                          labelText: 'Aro',
                          errorText: field.errorText,
                          helperText: 'Selecciona la medida del aro.',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Seleccionar'),
                          ),
                          ...arosBicicleta.map(
                            (aro) => DropdownMenuItem<String>(
                              value: aro,
                              child: Text(aro),
                            ),
                          ),
                        ],
                        onChanged: bloqueado
                            ? null
                            : (valor) {
                                final seleccionado = valor ?? '';
                                field.didChange(seleccionado);
                                campos.aro.text = seleccionado;
                                onCampoEditado();
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: campos.numeroSerie,
              focusNode: campos.focoNumeroSerie,
              readOnly:
                  bicicletaSeleccionadaId != null && operacion == 'RETIRO',
              onChanged: (_) => onCampoEditado(),
              decoration: decoracionCampoGestionManual(
                labelText: 'N° de serie',
                helperText: ayudaSiActivo(
                  campos.focoNumeroSerie,
                  'Código del marco, sin espacios.',
                ),
              ),
              validator: (valor) => validarCampoRequeridoConFormato(
                valor,
                requerido: creandoBicicletaNueva,
                mensajeRequerido: 'Ingresa el número de serie.',
                validarFormato: validarNumeroSerieBicicleta,
              ),
            ),
            const SizedBox(height: 12),
            SelectorFoto(
              fotoDataUrl: bicicletaSeleccionada?.fotoUrl ?? fotoNueva,
              onCamara: creandoBicicletaNueva
                  ? () => onElegirFoto(
                        ImageSource.camera,
                      )
                  : () {},
              onGaleria: creandoBicicletaNueva
                  ? () => onElegirFoto(
                        ImageSource.gallery,
                      )
                  : () {},
              onQuitar: !creandoBicicletaNueva || fotoNueva == null
                  ? null
                  : onQuitarFoto,
              errorText: errorFoto,
              mostrarAcciones: creandoBicicletaNueva,
            ),
          ],
        ),
      ],
    );
  }
}

String _resumenBicicleta(BicicletaApp bicicleta) {
  final estado = bicicleta.dentroBicicletero
      ? 'Dentro${bicicleta.bicicleteroActualNombre == null ? '' : ' - ${bicicleta.bicicleteroActualNombre}'}'
      : 'Fuera';
  final activa = bicicleta.activa ? 'Activa' : 'Inactiva';
  return '${bicicleta.descripcion} | $activa | $estado';
}
