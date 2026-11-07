import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/incidencias/presentation/etiquetas_incidencia.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/selector_fotos_multiples.dart';
import 'package:ubbike/shared/utilidades/revision_ortografica.dart';

const int maximoFotosIncidencia = 3;

const int maximoBytesFotoIncidencia = 2000000;

class FormularioIncidencia extends StatelessWidget {
  const FormularioIncidencia({
    super.key,
    required this.cargando,
    required this.enviando,
    required this.bicicleteros,
    required this.bicicletas,
    required this.bicicleteroSeleccionado,
    required this.bicicletaSeleccionada,
    required this.tipoSeleccionado,
    required this.controladorDescripcion,
    required this.fotos,
    required this.onCamara,
    required this.onGaleria,
    required this.onQuitarFoto,
    required this.permitirBicicletaPropia,
    required this.onBicicletero,
    required this.onBicicleta,
    required this.onTipo,
    required this.onEnviar,
    this.error,
  });

  final bool cargando;
  final bool enviando;
  final List<BicicleteroApp> bicicleteros;
  final List<BicicletaApp> bicicletas;
  final BicicleteroApp? bicicleteroSeleccionado;
  final BicicletaApp? bicicletaSeleccionada;
  final String tipoSeleccionado;
  final TextEditingController controladorDescripcion;
  final List<String> fotos;
  final VoidCallback onCamara;
  final VoidCallback onGaleria;
  final ValueChanged<int> onQuitarFoto;
  final bool permitirBicicletaPropia;
  final ValueChanged<BicicleteroApp?> onBicicletero;
  final ValueChanged<BicicletaApp?> onBicicleta;
  final ValueChanged<String> onTipo;
  final VoidCallback onEnviar;

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cargando)
          const Center(child: CircularProgressIndicator())
        else if (bicicleteros.isEmpty)
          const _AvisoFormularioIncidencia(
            icono: Icons.location_off_outlined,
            titulo: 'Sin bicicletero disponible',
            detalle:
                'No hay un bicicletero disponible para asociar el reporte.',
          )
        else ...[
          Container(
            decoration: BoxDecoration(
              color: ColoresUbb.azulApp.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return DropdownAnclado<BicicleteroApp>(
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(16),
                  menuMaxHeight: 300,
                  value: bicicleteroSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Bicicletero',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: Colors.white,
                  items: bicicleteros
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
                  onChanged: enviando ? null : onBicicletero,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (permitirBicicletaPropia)
            Container(
              decoration: BoxDecoration(
                color: ColoresUbb.azulApp.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return DropdownAnclado<BicicletaApp?>(
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    menuMaxHeight: 300,
                    value: bicicletaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Bicicleta asociada (opcional)',
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    dropdownColor: Colors.white,
                    items: [
                      const DropdownMenuItem<BicicletaApp?>(
                        value: null,
                        child: Text('Sin bicicleta asociada'),
                      ),
                      ...bicicletas.map(
                        (bicicleta) => DropdownMenuItem<BicicletaApp?>(
                          value: bicicleta,
                          child: Text(
                            bicicleta.descripcion,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                    onChanged: enviando ? null : onBicicleta,
                  );
                },
              ),
            ),
          if (permitirBicicletaPropia) const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: ColoresUbb.azulApp.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return DropdownAnclado<String>(
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(16),
                  menuMaxHeight: 300,
                  value: tipoSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de incidencia',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: Colors.white,
                  items: tiposIncidencia
                      .map(
                        (tipo) => DropdownMenuItem(
                          value: tipo,
                          child: Text(
                            etiquetaTipoIncidencia(tipo),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged:
                      enviando ? null : (valor) => onTipo(valor ?? 'OTRO'),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controladorDescripcion,
            spellCheckConfiguration: revisionOrtografica(),
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              hintText: 'Describe el problema con claridad.',
              alignLabelWithHint: true,
            ),
            validator: _validarDescripcionIncidencia,
          ),
          const SizedBox(height: 14),
          SelectorFotosMultiples(
            fotos: fotos,
            maximo: maximoFotosIncidencia,
            habilitado: !enviando,
            ayuda: 'Adjunta evidencia del problema. Puedes tomarla con la '
                'cámara o subirla desde tu galería.',
            onCamara: onCamara,
            onGaleria: onGaleria,
            onQuitar: onQuitarFoto,
          ),
          const SizedBox(height: 14),
          if (error != null) ...[
            ErrorFormulario(mensaje: error!),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            onPressed: enviando ? null : onEnviar,
            icon: enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(enviando ? 'Registrando' : 'Registrar incidencia'),
          ),
        ],
      ],
    );
  }
}

String? _validarDescripcionIncidencia(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa una descripción.';
  }
  if (texto.length < 8) {
    return 'Debe tener al menos 8 caracteres.';
  }
  if (texto.length > 1000) {
    return 'Máximo 1000 caracteres.';
  }
  return null;
}

class _AvisoFormularioIncidencia extends StatelessWidget {
  const _AvisoFormularioIncidencia({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresUbb.azulApp.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresUbb.borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: ColoresUbb.azulApp),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  detalle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColoresUbb.textoSecundario,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
