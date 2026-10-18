import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/utils/cercania_bicicletero.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/estilos_formulario.dart';

class BannerSugerenciaBicicletero extends StatelessWidget {
  const BannerSugerenciaBicicletero({
    super.key,
    required this.sugerencia,
    required this.onAceptar,
    required this.onDescartar,
  });

  final SugerenciaBicicletero sugerencia;
  final VoidCallback onAceptar;
  final VoidCallback onDescartar;

  String get _distanciaFormateada {
    final metros = sugerencia.distanciaMetros;
    return metros < 1000
        ? '${metros.round()} m'
        : '${(metros / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresUbb.azulApp.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresUbb.azulApp.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.near_me_outlined, color: ColoresUbb.azulApp),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estás cerca de ${sugerencia.bicicletero.nombre}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: ColoresUbb.azulNoche,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'A $_distanciaFormateada de tu ubicación. ¿Usar este bicicletero?',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColoresUbb.textoSecundario,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColoresUbb.azulApp,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: onAceptar,
                      child: const Text('Aceptar'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onDescartar,
                      child: const Text('Ahora no'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SelectorBicicleteroQr extends StatelessWidget {
  const SelectorBicicleteroQr({
    super.key,
    required this.bicicleteros,
    required this.bicicleteroSeleccionado,
    required this.onChanged,
  });

  final List<BicicleteroApp> bicicleteros;
  final BicicleteroApp? bicicleteroSeleccionado;
  final ValueChanged<BicicleteroApp?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seleccione el bicicletero a utilizar',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ColoresUbb.azulNoche,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return DropdownAnclado<BicicleteroApp>(
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              menuMaxHeight: 300,
              value: bicicleteroSeleccionado,
              decoration: decoracionCampoFormularioBicicleta(
                labelText: 'Bicicletero',
                prefixIcon: const Icon(
                  Icons.location_on_outlined,
                  color: ColoresUbb.azulApp,
                ),
              ),
              dropdownColor: Colors.white,
              items: bicicleteros
                  .map(
                    (bicicletero) => DropdownMenuItem(
                      value: bicicletero,
                      enabled: bicicletero.cuposDisponibles > 0,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${bicicletero.nombre} (${bicicletero.cuposDisponibles} cupos)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                color: bicicletero.cuposDisponibles > 0
                                    ? null
                                    : ColoresUbb.textoSecundario,
                              ),
                            ),
                          ),
                          if (bicicletero.cuposDisponibles == 0)
                            const Icon(
                              Icons.block_outlined,
                              size: 16,
                              color: ColoresUbb.rojoInstitucional,
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            );
          },
        ),
      ],
    );
  }
}
