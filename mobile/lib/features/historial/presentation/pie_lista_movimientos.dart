import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';

class PieListaMovimientos extends StatelessWidget {
  const PieListaMovimientos({
    super.key,
    required this.mostrados,
    required this.total,
    required this.hayMas,
    required this.cargando,
    required this.onCargarMas,
  });

  final int mostrados;
  final int total;
  final bool hayMas;
  final bool cargando;
  final VoidCallback onCargarMas;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hayMas
                ? 'Mostrando $mostrados de $total movimientos'
                : 'Mostrando los $total movimientos del filtro',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColoresUbb.textoSecundario,
                ),
          ),
          if (hayMas) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: cargando ? null : onCargarMas,
              icon: cargando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(cargando ? 'Cargando' : 'Cargar más'),
            ),
          ],
        ],
      ),
    );
  }
}
