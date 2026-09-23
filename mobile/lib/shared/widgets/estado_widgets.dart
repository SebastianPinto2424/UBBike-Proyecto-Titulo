import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';

class EstadoLista extends StatelessWidget {
  const EstadoLista({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColoresUbb.azulApp.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: ColoresUbb.azulApp, size: 42),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColoresUbb.textoSecundario,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class TituloApartado extends StatelessWidget {
  const TituloApartado({super.key, required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        titulo,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class DropdownAnclado<T> extends StatelessWidget {
  const DropdownAnclado({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.decoration,
    this.isExpanded = true,
    this.borderRadius,
    this.menuMaxHeight,
    this.dropdownColor,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final bool isExpanded;
  final BorderRadius? borderRadius;
  final double? menuMaxHeight;
  final Color? dropdownColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveDecoration = decoration
            .applyDefaults(
              Theme.of(context).inputDecorationTheme,
            )
            .copyWith(
              isDense: true,
              contentPadding: decoration.contentPadding ??
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            );
        final tieneSeleccion = items.any((item) => item.value == value);

        return InputDecorator(
          decoration: effectiveDecoration,
          isEmpty: !tieneSeleccion,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: isExpanded,
              isDense: true,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ColoresUbb.azulNoche,
                    fontWeight: FontWeight.w700,
                  ),
              borderRadius: borderRadius ?? BorderRadius.circular(16),
              menuMaxHeight: menuMaxHeight ?? 300,
              menuWidth: constraints.maxWidth,
              dropdownColor: dropdownColor ?? Colors.white,
            ),
          ),
        );
      },
    );
  }
}
