import 'package:flutter/material.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/inicio/application/tablero_administrador_vm.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/utilidades/utilidades_sesion.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/central_widgets.dart';
import 'package:ubbike/shared/widgets/encabezado_widgets.dart';
import 'package:ubbike/shared/widgets/panel_operativo_widgets.dart';
import 'package:ubbike/shared/widgets/atencion_operativa_widgets.dart';
import 'package:ubbike/shared/widgets/bicicleteros_operativos_widgets.dart';
import 'package:ubbike/shared/widgets/actividad_operativa_widgets.dart';
import 'package:ubbike/features/inicio/presentation/resumen_guardias_en_turno.dart';

class VistaTableroAdministrador extends ConsumerWidget {
  const VistaTableroAdministrador({
    super.key,
    this.onAbrirMovimientos,
    this.onAbrirGuardias,
    this.onAbrirSolicitudes,
    this.onAbrirIncidencias,
    this.onAbrirUsuarios,
    this.onAbrirBicicleteros,
  });

  final VoidCallback? onAbrirMovimientos;
  final VoidCallback? onAbrirGuardias;
  final VoidCallback? onAbrirSolicitudes;
  final VoidCallback? onAbrirIncidencias;
  final VoidCallback? onAbrirUsuarios;
  final VoidCallback? onAbrirBicicleteros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(tableroAdministradorVmProvider);
    final periodo = ref.watch(periodoTableroAdministradorProvider);
    final vm = ref.read(tableroAdministradorVmProvider.notifier);
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
                  nombre: nombreSesion(context, 'Administrador'),
                  sobreOscuro: true,
                ),
                const SizedBox(height: 16),
                EstadoInicioOperativo(
                  datos: datos?.central,
                  sobreOscuro: true,
                ),
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
                        return PanelTableroOperativoCargando(
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

                    final central = datos.central;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PanelAtencionOperativa(
                          datos: central,
                          onAbrirMovimientos: onAbrirMovimientos,
                          onAbrirGuardias: onAbrirGuardias,
                          onAbrirSolicitudes: onAbrirSolicitudes,
                          onAbrirIncidencias: onAbrirIncidencias,
                        ),
                        const SizedBox(height: 16),
                        _ResumenUsuariosAdmin(
                          datos: datos,
                          onVerUsuarios: onAbrirUsuarios,
                        ),
                        const SizedBox(height: 16),
                        EstadoBicicleterosOperativo(
                          bicicleteros: central.bicicleteros,
                          onVerDetalle: onAbrirBicicleteros,
                        ),
                        const SizedBox(height: 16),
                        ResumenGuardiasEnTurno(
                          bicicleteros: central.bicicleteros,
                          onGestionar: onAbrirGuardias,
                        ),
                        const SizedBox(height: 16),
                        EstadoCampusOperativo(datos: central),
                        const SizedBox(height: 14),
                        const TituloApartado(titulo: 'Resumen operacional'),
                        const SizedBox(height: 8),
                        SelectorPeriodoTablero(
                          seleccionado: periodo,
                          onChange: vm.cambiarPeriodo,
                        ),
                        const SizedBox(height: 12),
                        MetricasTableroOperativo(datos: central),
                        const SizedBox(height: 10),
                        BannerTasaExito(
                          confirmados: central.resumen.confirmados,
                          denegados: central.resumen.denegados,
                          total: central.resumen.totalMovimientos,
                        ),
                        CanalesValidacionOperativo(resumen: central.resumen),
                        const SizedBox(height: 16),
                        ActividadPeriodoOperativo(resumen: central.resumen),
                        const SizedBox(height: 16),
                        ActividadRecienteOperativo(
                          movimientos: central.movimientosRecientes,
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

class _ResumenUsuariosAdmin extends StatelessWidget {
  const _ResumenUsuariosAdmin({
    required this.datos,
    this.onVerUsuarios,
  });

  final DatosTableroAdministrador datos;
  final VoidCallback? onVerUsuarios;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: TituloApartado(titulo: 'Usuarios del sistema'),
            ),
            if (onVerUsuarios != null)
              TextButton(
                onPressed: onVerUsuarios,
                child: const Text('Gestionar'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GridIndicadoresCentral(
          indicadores: [
            IndicadorCentral(
              valor: datos.usuariosActivos.toString(),
              etiqueta: 'Activos',
              icono: Icons.how_to_reg_outlined,
              colorIcono: ColoresUbb.exito,
            ),
            IndicadorCentral(
              valor: datos.usuariosInactivos.toString(),
              etiqueta: 'Inactivos',
              icono: Icons.person_off_outlined,
              colorIcono: ColoresUbb.textoSecundario,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
            child: ListTile(
          leading: const Icon(Icons.mark_email_unread_outlined,
              color: ColoresUbb.amarilloInstitucional),
          title: const Text('Pendientes de verificación'),
          trailing: Text(datos.usuariosPendientesVerificacion.toString()),
          onTap: onVerUsuarios,
        )),
      ],
    );
  }
}
