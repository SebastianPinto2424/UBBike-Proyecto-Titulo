import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/inicio/application/dashboard_central_vm.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/utils/sesion_ui_utils.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/central_widgets.dart';
import 'package:ubbike/shared/widgets/encabezado_widgets.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/panel_operativo_widgets.dart';

class VistaDashboardCentral extends ConsumerWidget {
  const VistaDashboardCentral({
    super.key,
    this.onAbrirMovimientos,
    this.onAbrirGuardias,
    this.onAbrirSolicitudes,
    this.onAbrirIncidencias,
  });

  final VoidCallback? onAbrirMovimientos;
  final VoidCallback? onAbrirGuardias;
  final VoidCallback? onAbrirSolicitudes;
  final VoidCallback? onAbrirIncidencias;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(dashboardCentralVmProvider);
    final periodo = ref.watch(periodoDashboardCentralProvider);
    final vm = ref.read(dashboardCentralVmProvider.notifier);
    final datos = estado.valueOrNull;

    return RefreshIndicator(
      onRefresh: vm.refrescar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          PanelInicioOscuro(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EncabezadoSeccion(
                  saludo: saludoActual(),
                  nombre: nombreSesion(context, 'Central'),
                  sobreOscuro: true,
                ),
                const SizedBox(height: 16),
                EstadoInicioOperativo(datos: datos, sobreOscuro: true),
              ],
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Builder(
                  builder: (context) {
                    if (datos == null) {
                      if (estado.isLoading) {
                        return PanelDashboardOperativoCargando(
                          periodo: periodo,
                          onPeriodo: vm.cambiarPeriodo,
                        );
                      }
                      return TarjetaAccion(
                        icono: Icons.error_outline,
                        titulo: 'No se pudo cargar el tablero',
                        detalle: 'Toca para reintentar.',
                        color: ColoresUbb.rojoInstitucional,
                        onTap: vm.refrescar,
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PanelAtencionOperativa(
                          datos: datos,
                          onAbrirMovimientos: onAbrirMovimientos,
                          onAbrirGuardias: onAbrirGuardias,
                          onAbrirSolicitudes: onAbrirSolicitudes,
                          onAbrirIncidencias: onAbrirIncidencias,
                        ),
                        const SizedBox(height: 16),
                        EstadoBicicleterosOperativo(
                          bicicleteros: datos.bicicleteros,
                          onVerGuardias: onAbrirGuardias,
                        ),
                        const SizedBox(height: 16),
                        EstadoCampusOperativo(datos: datos),
                        const SizedBox(height: 14),
                        const TituloApartado(titulo: 'Resumen operacional'),
                        const SizedBox(height: 8),
                        SelectorPeriodoDashboard(
                          seleccionado: periodo,
                          onChange: vm.cambiarPeriodo,
                        ),
                        const SizedBox(height: 12),
                        MetricasDashboardOperativo(datos: datos),
                        const SizedBox(height: 10),
                        BannerTasaExito(
                          confirmados: datos.resumen.confirmados,
                          denegados: datos.resumen.denegados,
                          total: datos.resumen.totalMovimientos,
                        ),
                        CanalesValidacionOperativo(resumen: datos.resumen),
                        const SizedBox(height: 16),
                        ActividadPeriodoOperativo(resumen: datos.resumen),
                        const SizedBox(height: 16),
                        ActividadRecienteOperativo(
                          movimientos: datos.movimientosRecientes,
                          onVerMovimientos: onAbrirMovimientos,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
