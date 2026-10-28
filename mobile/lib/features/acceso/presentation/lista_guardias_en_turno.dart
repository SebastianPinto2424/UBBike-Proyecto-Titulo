import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';

class ListaGuardiasEnTurno extends StatelessWidget {
  const ListaGuardiasEnTurno({
    super.key,
    required this.bicicleteros,
    required this.liberandoId,
    required this.habilitado,
    required this.onLiberar,
  });

  final List<BicicleteroApp> bicicleteros;
  final String? liberandoId;
  final bool habilitado;
  final ValueChanged<BicicleteroApp> onLiberar;

  @override
  Widget build(BuildContext context) {
    final cubiertos = bicicleteros.where((item) => item.tieneGuardia).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloApartado(titulo: 'Guardias en turno'),
        const SizedBox(height: 2),
        Text(
          '${cubiertos.length} de ${bicicleteros.length} bicicleteros con guardia',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColoresUbb.textoSecundario,
              ),
        ),
        const SizedBox(height: 10),
        if (cubiertos.isEmpty)
          const EstadoLista(
            icono: Icons.shield_outlined,
            titulo: 'Ningún bicicletero tiene guardia',
            detalle: 'Asigna uno con el formulario de arriba.',
          )
        else
          Card(
            child: Column(
              children: [
                for (final (indice, bicicletero) in cubiertos.indexed) ...[
                  if (indice > 0) const Divider(height: 1),
                  _FilaGuardiaEnTurno(
                    bicicletero: bicicletero,
                    liberando: liberandoId == bicicletero.id,
                    habilitado: habilitado,
                    onLiberar: () => onLiberar(bicicletero),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _FilaGuardiaEnTurno extends StatelessWidget {
  const _FilaGuardiaEnTurno({
    required this.bicicletero,
    required this.liberando,
    required this.habilitado,
    required this.onLiberar,
  });

  final BicicleteroApp bicicletero;
  final bool liberando;
  final bool habilitado;
  final VoidCallback onLiberar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, color: ColoresUbb.azulApp),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bicicletero.nombre,
                  style: textTheme.bodyMedium?.copyWith(
                    color: ColoresUbb.azulNoche,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bicicletero.guardiaActivoNombre ?? '',
                  style: textTheme.bodySmall?.copyWith(
                    color: ColoresUbb.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (liberando)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: ColoresUbb.rojoInstitucional,
              ),
              onPressed: habilitado ? onLiberar : null,
              child: const Text('Liberar'),
            ),
        ],
      ),
    );
  }
}
