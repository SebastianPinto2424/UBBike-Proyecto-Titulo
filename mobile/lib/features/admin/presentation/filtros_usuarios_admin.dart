import 'package:flutter/material.dart';

import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/admin/application/gestion_usuarios_vm.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';

class FiltrosUsuariosAdmin extends StatelessWidget {
  const FiltrosUsuariosAdmin({
    super.key,
    required this.controladorBusqueda,
    required this.total,
    required this.cargando,
    required this.tieneFiltros,
    required this.rol,
    required this.estadoCuenta,
    required this.estadoCorreo,
    required this.activos,
    required this.onBuscar,
    required this.onRol,
    required this.onEstadoCuenta,
    required this.onEstadoCorreo,
    required this.onLimpiarBusqueda,
    required this.onLimpiar,
  });

  final TextEditingController controladorBusqueda;
  final int total;
  final bool cargando;
  final bool tieneFiltros;
  final RolUsuario? rol;
  final FiltroEstadoCuenta estadoCuenta;
  final FiltroEstadoCorreo estadoCorreo;
  final List<FiltroActivo> activos;
  final ValueChanged<String> onBuscar;
  final ValueChanged<RolUsuario?> onRol;
  final ValueChanged<FiltroEstadoCuenta> onEstadoCuenta;
  final ValueChanged<FiltroEstadoCorreo> onEstadoCorreo;
  final VoidCallback onLimpiarBusqueda;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    final contador = cargando ? 'Buscando...' : '$total usuarios';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Buscar usuarios',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: ColoresUbb.azulNoche,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Text(
                  contador,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColoresUbb.textoSecundario,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controladorBusqueda,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onChanged: onBuscar,
              decoration: InputDecoration(
                labelText: 'Nombre, correo o RUT',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controladorBusqueda.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: onLimpiarBusqueda,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            _PanelFiltrosUsuarios(
              titulo: 'Filtros',
              detalle: _resumenFiltros(),
              activos: activos,
              onLimpiar: tieneFiltros ? onLimpiar : null,
              children: [
                _EtiquetaFiltroUsuarios(
                  texto: 'Rol',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChipFiltroUsuarios<RolUsuario?>(
                        label: 'Todos',
                        value: null,
                        selectedValue: rol,
                        onTap: onRol,
                      ),
                      for (final item in RolUsuario.values)
                        _ChipFiltroUsuarios<RolUsuario?>(
                          label: item.etiqueta,
                          value: item,
                          selectedValue: rol,
                          onTap: onRol,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _EtiquetaFiltroUsuarios(
                  texto: 'Estado cuenta',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in FiltroEstadoCuenta.values)
                        _ChipFiltroUsuarios<FiltroEstadoCuenta>(
                          label: item.etiqueta,
                          value: item,
                          selectedValue: estadoCuenta,
                          onTap: onEstadoCuenta,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _EtiquetaFiltroUsuarios(
                  texto: 'Estado correo',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in FiltroEstadoCorreo.values)
                        _ChipFiltroUsuarios<FiltroEstadoCorreo>(
                          label: item.etiqueta,
                          value: item,
                          selectedValue: estadoCorreo,
                          onTap: onEstadoCorreo,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _resumenFiltros() {
    final rolTexto = rol?.etiqueta ?? 'Todos los roles';
    return '$rolTexto | ${estadoCuenta.etiqueta} | ${estadoCorreo.etiqueta}';
  }
}

class _PanelFiltrosUsuarios extends StatelessWidget {
  const _PanelFiltrosUsuarios({
    required this.titulo,
    required this.detalle,
    required this.children,
    this.onLimpiar,
    this.activos = const <FiltroActivo>[],
  });

  final String titulo;
  final String detalle;
  final List<Widget> children;
  final VoidCallback? onLimpiar;
  final List<FiltroActivo> activos;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColoresUbb.superficie,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColoresUbb.bordeFuerte),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.tune, color: ColoresUbb.azulApp),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ColoresUbb.azulNoche,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (activos.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: ColoresUbb.azulApp,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${activos.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              detalle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColoresUbb.textoSecundario,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            children: [
              const SizedBox(height: 4),
              ...children,
              if (onLimpiar != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onLimpiar,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Restablecer filtros'),
                  ),
                ),
              ],
            ],
          ),
          if (activos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filtro in activos)
                    InputChip(
                      label: Text(filtro.etiqueta),
                      onDeleted: filtro.onQuitar,
                      deleteIcon: const Icon(Icons.close, size: 16),
                      deleteButtonTooltipMessage: 'Quitar filtro',
                      visualDensity: VisualDensity.compact,
                      backgroundColor:
                          ColoresUbb.azulApp.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: ColoresUbb.azulApp.withValues(alpha: 0.28),
                      ),
                      labelStyle:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: ColoresUbb.azulNoche,
                                fontWeight: FontWeight.w700,
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

class _EtiquetaFiltroUsuarios extends StatelessWidget {
  const _EtiquetaFiltroUsuarios({required this.texto, required this.child});

  final String texto;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          texto,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColoresUbb.textoSecundario,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ChipFiltroUsuarios<T> extends StatelessWidget {
  const _ChipFiltroUsuarios({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onTap,
  });

  final String label;
  final T value;
  final T selectedValue;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    final seleccionado = value == selectedValue;
    return ChoiceChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (_) => onTap(value),
      showCheckmark: false,
      selectedColor: ColoresUbb.azulApp,
      backgroundColor: ColoresUbb.superficieAzulSuave,
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: seleccionado ? Colors.white : ColoresUbb.azulApp,
            fontWeight: FontWeight.w800,
          ),
      side: BorderSide(
        color: seleccionado ? ColoresUbb.azulApp : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
