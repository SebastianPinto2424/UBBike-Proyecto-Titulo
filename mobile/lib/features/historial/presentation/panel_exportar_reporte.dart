import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';

class PanelExportarReporte extends StatelessWidget {
  const PanelExportarReporte({
    super.key,
    required this.exportando,
    required this.expandido,
    required this.formatoSeleccionado,
    required this.onToggle,
    required this.onFormato,
    required this.onDescargar,
    required this.onCompartir,
  });

  final bool exportando;
  final bool expandido;
  final String? formatoSeleccionado;
  final VoidCallback onToggle;
  final ValueChanged<String?> onFormato;
  final VoidCallback onDescargar;
  final VoidCallback onCompartir;

  @override
  Widget build(BuildContext context) {
    final etiquetaFormato = switch (formatoSeleccionado) {
      'EXCEL' => 'Excel',
      'PDF' => 'PDF',
      _ => 'Excel o PDF',
    };

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: exportando ? null : onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  if (exportando) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ColoresUbb.azulApp,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exportando ? 'Exportando' : 'Exportar',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: ColoresUbb.azulNoche,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Usa los filtros actuales',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: ColoresUbb.textoSecundario,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    etiquetaFormato,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColoresUbb.azulApp,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expandido
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: ColoresUbb.azulApp,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: expandido
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _OpcionFormatoExportacion(
                    titulo: 'Excel',
                    detalle: 'Archivo editable con los movimientos filtrados.',
                    seleccionado: formatoSeleccionado == 'EXCEL',
                    onChanged: exportando
                        ? null
                        : (activo) => onFormato(activo ? 'EXCEL' : null),
                  ),
                  const SizedBox(height: 10),
                  _OpcionFormatoExportacion(
                    titulo: 'PDF',
                    detalle: 'Reporte con formato, listo para imprimir.',
                    seleccionado: formatoSeleccionado == 'PDF',
                    onChanged: exportando
                        ? null
                        : (activo) => onFormato(activo ? 'PDF' : null),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: formatoSeleccionado == null || exportando
                              ? null
                              : onDescargar,
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: Text(
                            exportando ? 'Exportando...' : 'Descargar',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: formatoSeleccionado == null || exportando
                              ? null
                              : onCompartir,
                          icon: const Icon(Icons.ios_share, size: 18),
                          label: const Text(
                            'Compartir',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpcionFormatoExportacion extends StatelessWidget {
  const _OpcionFormatoExportacion({
    required this.titulo,
    required this.detalle,
    required this.seleccionado,
    required this.onChanged,
  });

  final String titulo;
  final String detalle;
  final bool seleccionado;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!seleccionado),
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionado
              ? ColoresUbb.azulApp.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: seleccionado ? ColoresUbb.azulApp : ColoresUbb.borde,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ColoresUbb.azulNoche,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColoresUbb.textoSecundario,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch.adaptive(
              value: seleccionado,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: ColoresUbb.azulApp,
            ),
          ],
        ),
      ),
    );
  }
}
