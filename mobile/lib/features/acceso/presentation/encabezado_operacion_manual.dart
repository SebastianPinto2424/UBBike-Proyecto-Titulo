import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/acceso/application/gestion_manual_vm.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/features/acceso/presentation/gestion_manual_widgets.dart';

class EncabezadoOperacionManual extends ConsumerWidget {
  const EncabezadoOperacionManual({
    super.key,
    required this.operacion,
    required this.mostrarOperacion,
    required this.autodetectada,
    required this.requiereBicicletero,
    required this.bicicleteroId,
    required this.onBicicletero,
  });

  final String operacion;
  final bool mostrarOperacion;
  final bool autodetectada;
  final bool requiereBicicletero;
  final String? bicicleteroId;
  final ValueChanged<String?> onBicicletero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(bicicleterosGestionManualProvider, (_, siguiente) {
      final lista = siguiente.valueOrNull ?? const <BicicleteroApp>[];
      if (!lista.any((item) => item.id == bicicleteroId)) {
        onBicicletero(null);
      }
    });
    final bicicleteros = ref.watch(bicicleterosGestionManualProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mostrarOperacion) ...[
          _IndicadorOperacionManual(
            operacion: operacion,
            autodetectada: autodetectada,
          ),
          const SizedBox(height: 14),
        ],
        if (requiereBicicletero) ...[
          _SelectorBicicleteroManual(
            bicicleteros: bicicleteros.valueOrNull ?? const [],
            value: bicicleteroId,
            cargando: bicicleteros.isLoading && !bicicleteros.hasValue,
            error: bicicleteros.hasError
                ? 'No se pudieron cargar los bicicleteros.'
                : null,
            onChanged: onBicicletero,
            onRecargar: () => ref.invalidate(bicicleterosGestionManualProvider),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SelectorBicicleteroManual extends StatelessWidget {
  const _SelectorBicicleteroManual({
    required this.bicicleteros,
    required this.value,
    required this.cargando,
    required this.error,
    required this.onChanged,
    required this.onRecargar,
  });

  final List<BicicleteroApp> bicicleteros;
  final String? value;
  final bool cargando;
  final String? error;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRecargar;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const CajaBusquedaManual(
        icono: Icons.hourglass_empty_outlined,
        color: ColoresUbb.azulApp,
        children: [
          Text('Cargando bicicleteros disponibles...'),
        ],
      );
    }

    if (error != null) {
      return CajaBusquedaManual(
        icono: Icons.error_outline,
        color: ColoresUbb.rojoInstitucional,
        children: [
          Text(error!),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRecargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    if (bicicleteros.isEmpty) {
      return const CajaBusquedaManual(
        icono: Icons.info_outline,
        color: ColoresUbb.azulApp,
        children: [
          Text('No hay bicicleteros activos para registrar el ingreso.'),
        ],
      );
    }

    final valorSeguro =
        bicicleteros.any((bicicletero) => bicicletero.id == value)
            ? value
            : null;

    return DropdownAnclado<String>(
      value: valorSeguro,
      borderRadius: BorderRadius.circular(16),
      menuMaxHeight: 320,
      decoration: decoracionCampoGestionManual(
        labelText: 'Bicicletero del ingreso',
        prefixIcon: const Icon(Icons.local_parking_outlined),
      ),
      items: bicicleteros
          .map(
            (bicicletero) => DropdownMenuItem<String>(
              value: bicicletero.id,
              child: Text(
                '${bicicletero.nombre} | ${bicicletero.cuposDisponibles} cupos',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _IndicadorOperacionManual extends StatelessWidget {
  const _IndicadorOperacionManual({
    required this.operacion,
    required this.autodetectada,
  });

  final String operacion;
  final bool autodetectada;

  @override
  Widget build(BuildContext context) {
    final esIngreso = operacion == 'INGRESO';
    final color = esIngreso ? ColoresUbb.exito : ColoresUbb.azulApp;
    final textoBase = esIngreso ? 'Ingreso' : 'Retiro';
    final textoOperacion = autodetectada ? '$textoBase detectado' : textoBase;

    return Align(
      alignment: Alignment.centerLeft,
      child: ChipEstado(
        texto: textoOperacion,
        color: color,
      ),
    );
  }
}
