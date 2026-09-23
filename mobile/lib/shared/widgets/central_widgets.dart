import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';

class GridIndicadoresCentral extends StatelessWidget {
  const GridIndicadoresCentral({super.key, required this.indicadores});

  final List<Widget> indicadores;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxColumnas = constraints.maxWidth < 600 ? 2 : 3;
        final columnas = indicadores.length.clamp(1, maxColumnas);
        final ancho = (constraints.maxWidth - 8 * (columnas - 1)) / columnas;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final indicador in indicadores)
              SizedBox(width: ancho, child: indicador)
          ],
        );
      },
    );
  }
}

class IndicadorCentral extends StatelessWidget {
  const IndicadorCentral({
    super.key,
    required this.valor,
    required this.etiqueta,
    required this.icono,
    required this.colorIcono,
  });

  final String valor;
  final String etiqueta;
  final IconData icono;
  final Color colorIcono;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorIcono.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icono, color: colorIcono, size: 14),
            ),
            const SizedBox(height: 5),
            Text(
              valor,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: ColoresUbb.azulNoche,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColoresUbb.textoSecundario,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class BannerTasaExito extends StatelessWidget {
  const BannerTasaExito({
    super.key,
    required this.confirmados,
    required this.denegados,
    required this.total,
  });

  final int confirmados;
  final int denegados;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final tasa = (confirmados / total).clamp(0.0, 1.0);
    final tasaPct = (tasa * 100).toStringAsFixed(1);
    final color = tasa >= 0.9
        ? ColoresUbb.exito
        : tasa >= 0.7
            ? ColoresUbb.amarilloInstitucional
            : ColoresUbb.rojoInstitucional;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tasa de éxito',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Text(
                  '$tasaPct%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: tasa,
                minHeight: 8,
                backgroundColor:
                    ColoresUbb.rojoInstitucional.withValues(alpha: 0.18),
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  '$confirmados aprobados',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColoresUbb.textoSecundario,
                      ),
                ),
                const Spacer(),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: ColoresUbb.rojoInstitucional,
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  '$denegados rechazados',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColoresUbb.textoSecundario,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SelectorPeriodoDashboard extends StatelessWidget {
  const SelectorPeriodoDashboard({
    super.key,
    required this.seleccionado,
    required this.onChange,
  });

  final String seleccionado;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'DIA', label: Text('Día')),
          ButtonSegment(value: 'SEMANA', label: Text('Semana')),
          ButtonSegment(value: 'MES', label: Text('Mes')),
          ButtonSegment(value: 'ANIO', label: Text('Año')),
        ],
        selected: {seleccionado},
        onSelectionChanged: (val) => onChange(val.first),
        showSelectedIcon: false,
      ),
    );
  }
}

class FilaDato extends StatelessWidget {
  const FilaDato({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.anchoCompleto = false,
    this.valorColor,
    this.valorPeso = FontWeight.w800,
  });

  final String etiqueta;
  final String valor;
  final bool anchoCompleto;
  final Color? valorColor;
  final FontWeight valorPeso;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compacto = anchoCompleto ||
              constraints.maxWidth < 380 ||
              valor.length > 28 ||
              valor.contains('@');
          final etiquetaWidget = Text(
            etiqueta,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ColoresUbb.textoSecundario,
                ),
          );
          final valorWidget = Text(
            valor,
            textAlign: compacto ? TextAlign.start : TextAlign.end,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valorColor,
                  fontWeight: valorPeso,
                ),
          );

          if (compacto) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                etiquetaWidget,
                const SizedBox(height: 2),
                valorWidget,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: etiquetaWidget),
              Flexible(child: valorWidget),
            ],
          );
        },
      ),
    );
  }
}
