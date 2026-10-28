import 'package:flutter/material.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/features/acceso/application/solicitudes_guardia_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/utilidades/auto_refresco.dart';
import 'package:ubbike/shared/widgets/encabezado_widgets.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/features/acceso/presentation/vista_ingreso_guardia.dart';
import 'package:ubbike/shared/utilidades/utilidades_sesion.dart';
import 'package:ubbike/shared/widgets/bicicletero_widgets.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/features/acceso/presentation/selector_bicicletero_guardia.dart';

class VistaInicioGuardia extends ConsumerStatefulWidget {
  const VistaInicioGuardia({
    super.key,
    this.onOpenIngreso,
  });

  final ValueChanged<ModoIngresoGuardia>? onOpenIngreso;

  @override
  ConsumerState<VistaInicioGuardia> createState() => _VistaInicioGuardiaState();
}

class _VistaInicioGuardiaState extends ConsumerState<VistaInicioGuardia>
    with AutoRefrescoMixin {
  SolicitudesGuardiaVm get vm => ref.read(solicitudesGuardiaVmProvider);
  late Future<BicicleteroApp?> futuroBicicletero;
  late Future<List<BicicleteroApp>> futuroBicicleteros;
  BicicleteroApp? ultimoBicicletero;
  List<BicicleteroApp>? ultimosBicicleteros;
  bool bicicleteroConsultado = false;
  bool ultimaRecargaFallida = false;
  int versionSelector = 0;

  @override
  void initState() {
    super.initState();
    futuroBicicletero = vm.obtenerBicicleteroGestionado();
    futuroBicicleteros = vm.listarBicicleteros();
    iniciarAutoRefresco();
  }

  @override
  bool get datosDesactualizados => ultimaRecargaFallida;

  @override
  Future<void> refrescar() async {
    _refrescarEnSilencio();
    try {
      await Future.wait([futuroBicicletero, futuroBicicleteros]);
      ultimaRecargaFallida = false;
    } catch (_) {
      ultimaRecargaFallida = true;
    }
  }

  Future<void> _recargar() async {
    setState(() {
      versionSelector++;
      futuroBicicletero = vm.obtenerBicicleteroGestionado();
      futuroBicicleteros = vm.listarBicicleteros();
    });
  }

  void _refrescarEnSilencio() {
    setState(() {
      futuroBicicletero = vm.obtenerBicicleteroGestionado();
      futuroBicicleteros = vm.listarBicicleteros();
    });
  }

  void _alCambiarBicicletero() {
    setState(() {
      futuroBicicletero = vm.obtenerBicicleteroGestionado();
    });
  }

  @override
  Widget build(BuildContext context) {
    for (final version in [
      bicicleterosVersionProvider,
      movimientosVersionProvider
    ]) {
      ref.listen<int>(version, (_, __) => solicitarRefresco());
    }

    return ColoredBox(
      color: ColoresUbb.fondo,
      child: RefreshIndicator(
        color: ColoresUbb.azulApp,
        backgroundColor: ColoresUbb.fondo,
        onRefresh: _recargar,
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
                    nombre: nombreSesion(context, 'Guardia'),
                    sobreOscuro: true,
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<BicicleteroApp?>(
                    future: futuroBicicletero,
                    builder: (context, snapshot) {
                      final esperando =
                          snapshot.connectionState == ConnectionState.waiting;
                      if (!esperando && !snapshot.hasError) {
                        ultimoBicicletero = snapshot.data;
                        bicicleteroConsultado = true;
                      }
                      final bicicletero = esperando || snapshot.hasError
                          ? ultimoBicicletero
                          : snapshot.data;
                      final tieneBicicletero = bicicletero != null;
                      final primeraCarga = esperando && !bicicleteroConsultado;

                      return EstadoInicioLiviano(
                        icono: tieneBicicletero || primeraCarga
                            ? Icons.verified_user_outlined
                            : Icons.location_off_outlined,
                        color: tieneBicicletero
                            ? ColoresUbb.turquesa
                            : ColoresUbb.azulApp,
                        titulo: primeraCarga
                            ? 'Turno'
                            : tieneBicicletero
                                ? 'Turno activo'
                                : 'Turno sin iniciar',
                        detalle: primeraCarga
                            ? 'Validando bicicletero asignado.'
                            : tieneBicicletero
                                ? 'Gestionas ${bicicletero.nombre} · ${bicicletero.cuposDisponibles == 1 ? '1 cupo libre' : '${bicicletero.cuposDisponibles} cupos libres'}'
                                : 'Selecciona un bicicletero para comenzar a validar.',
                        sobreOscuro: true,
                      );
                    },
                  ),
                ],
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectorBicicleteroGuardiaPerfil(
                        key: ValueKey('selector-guardia-$versionSelector'),
                        onCambiado: _alCambiarBicicletero,
                      ),
                      const SizedBox(height: 10),
                      TarjetaAccion(
                        icono: Icons.qr_code_scanner,
                        titulo: 'Escanear QR temporal',
                        detalle:
                            'Lee el código del usuario para confirmar o denegar ingreso/retiro.',
                        color: ColoresUbb.exito,
                        onTap: () =>
                            widget.onOpenIngreso?.call(ModoIngresoGuardia.qr),
                      ),
                      const SizedBox(height: 10),
                      TarjetaAccion(
                        icono: Icons.edit_note_outlined,
                        titulo: 'Gestión manual',
                        detalle:
                            'Registra ingreso o retiro utilizando correo institucional o RUT.',
                        color: ColoresUbb.azulApp,
                        onTap: () => widget.onOpenIngreso
                            ?.call(ModoIngresoGuardia.manual),
                      ),
                      const SizedBox(height: 18),
                      const TituloApartado(titulo: 'Uso de bicicleteros'),
                      const SizedBox(height: 10),
                      FutureBuilder<List<BicicleteroApp>>(
                        future: futuroBicicleteros,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            ultimosBicicleteros = snapshot.data;
                          }
                          final anteriores = ultimosBicicleteros;
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            if (anteriores == null) {
                              return const SizedBox.shrink();
                            }
                            return _ListaBicicleterosGuardia(
                              bicicleteros: anteriores,
                            );
                          }
                          if (snapshot.hasError && anteriores != null) {
                            return _ListaBicicleterosGuardia(
                              bicicleteros: anteriores,
                            );
                          }
                          if (snapshot.hasError) {
                            return TarjetaAccion(
                              icono: Icons.cloud_off_outlined,
                              titulo: 'No se pudieron cargar bicicleteros',
                              detalle: 'Toca para reintentar.',
                              color: ColoresUbb.rojoInstitucional,
                              onTap: _recargar,
                            );
                          }
                          final bicicleteros = snapshot.data ?? [];
                          if (bicicleteros.isEmpty) {
                            return const EstadoLista(
                              icono: Icons.location_off_outlined,
                              titulo: 'Sin bicicleteros activos',
                              detalle:
                                  'Cuando existan bicicleteros activos aparecerán aquí.',
                            );
                          }
                          return _ListaBicicleterosGuardia(
                            bicicleteros: bicicleteros,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaBicicleterosGuardia extends StatelessWidget {
  const _ListaBicicleterosGuardia({required this.bicicleteros});

  final List<BicicleteroApp> bicicleteros;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: bicicleteros
          .map(
            (bicicletero) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaBicicleteroApp(bicicletero: bicicletero),
            ),
          )
          .toList(),
    );
  }
}
