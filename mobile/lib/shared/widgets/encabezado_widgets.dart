import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';

class PanelInicioOscuro extends StatelessWidget {
  const PanelInicioOscuro({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
      decoration: BoxDecoration(
        color: ColoresUbb.azulNoche,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: ColoresUbb.azulNoche.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class EncabezadoSeccion extends StatelessWidget {
  const EncabezadoSeccion({
    super.key,
    required this.saludo,
    required this.nombre,
    this.detalle,
    this.sobreOscuro = false,
  });

  final String saludo;
  final String nombre;
  final String? detalle;
  final bool sobreOscuro;

  @override
  Widget build(BuildContext context) {
    final colorSuave = sobreOscuro
        ? Colors.white.withValues(alpha: 0.75)
        : ColoresUbb.textoSecundario;
    final colorFuerte = sobreOscuro ? Colors.white : ColoresUbb.textoPrincipal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$saludo,',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorSuave,
              ),
        ),
        Text(
          nombre,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colorFuerte,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
        ),
        if (detalle != null) ...[
          const SizedBox(height: 4),
          Text(
            detalle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorSuave,
                ),
          ),
        ],
      ],
    );
  }
}

class EstadoInicioLiviano extends StatelessWidget {
  const EstadoInicioLiviano({
    super.key,
    this.icono,
    required this.color,
    required this.titulo,
    required this.detalle,
    this.sobreOscuro = false,
  });

  final IconData? icono;
  final Color color;
  final String titulo;
  final String detalle;
  final bool sobreOscuro;

  @override
  Widget build(BuildContext context) {
    final colorTitulo = sobreOscuro ? Colors.white : ColoresUbb.textoPrincipal;
    final colorDetalle = sobreOscuro
        ? Colors.white.withValues(alpha: 0.75)
        : ColoresUbb.textoSecundario;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icono != null)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: sobreOscuro ? 0.22 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: color, size: 24),
          )
        else
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorTitulo,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                detalle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorDetalle,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
