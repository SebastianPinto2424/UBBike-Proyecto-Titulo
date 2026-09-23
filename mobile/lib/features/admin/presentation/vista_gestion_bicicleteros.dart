import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/admin/application/gestion_bicicleteros_vm.dart';
import 'package:ubbike/features/admin/presentation/formulario_bicicletero_sheet.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/widgets/bicicletero_widgets.dart';
import 'package:ubbike/shared/widgets/dialogo_eliminar.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';

class VistaGestionBicicleteros extends ConsumerStatefulWidget {
  const VistaGestionBicicleteros({super.key});

  @override
  ConsumerState<VistaGestionBicicleteros> createState() =>
      _VistaGestionBicicleterosState();
}

class _VistaGestionBicicleterosState
    extends ConsumerState<VistaGestionBicicleteros> {
  GestionBicicleterosVm get vm =>
      ref.read(gestionBicicleterosVmProvider.notifier);

  Future<void> _abrirFormulario({BicicleteroApp? bicicletero}) async {
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (_) => FormularioBicicleteroSheet(
        bicicletero: bicicletero,
        alGuardar: (datos) async {
          if (bicicletero == null) {
            await vm.crear(
                nombre: datos.nombre,
                ubicacion: datos.ubicacion,
                capacidad: datos.capacidad,
                latitud: datos.latitud,
                longitud: datos.longitud);
          } else {
            await vm.actualizar(
                bicicleteroId: bicicletero.id,
                nombre: datos.nombre,
                ubicacion: datos.ubicacion,
                capacidad: datos.capacidad,
                latitud: datos.latitud,
                longitud: datos.longitud);
          }
        },
      ),
    );
    if (resultado == true && mounted) {
      context.mostrarExito(bicicletero == null
          ? 'Bicicletero creado'
          : 'Bicicletero actualizado');
    }
  }

  Future<void> _eliminar(BicicleteroApp bicicletero) async {
    final confirmar = await confirmarEliminacion(
      context,
      titulo: 'Eliminar bicicletero',
      nombre: bicicletero.nombre,
      consecuencia:
          'Dejará de estar disponible para nuevos ingresos y no aparecerá en la app. El historial de movimientos se conserva.',
    );

    if (!confirmar || !mounted) {
      return;
    }

    try {
      await vm.eliminar(bicicletero.id);
      if (mounted) {
        context.mostrarExito('Bicicletero eliminado');
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError('No se pudo conectar con el backend');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(gestionBicicleterosVmProvider);
    final bicicleteros = estado.valueOrNull ?? const <BicicleteroApp>[];
    final cargando = estado.isLoading && estado.valueOrNull == null;
    final tieneError = estado.hasError && estado.valueOrNull == null;

    return Column(
      children: [
        _EncabezadoAdminBicicleteros(onCrear: () => _abrirFormulario()),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => vm.recargar(),
            child: Builder(
              builder: (context) {
                if (cargando) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(
                        height: 180,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  );
                }

                if (tieneError) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      TarjetaAccion(
                        icono: Icons.cloud_off_outlined,
                        titulo: 'No se pudieron cargar bicicleteros',
                        detalle: 'Toca para reintentar.',
                        color: ColoresUbb.rojoInstitucional,
                        onTap: vm.recargar,
                      ),
                    ],
                  );
                }

                if (bicicleteros.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      EstadoLista(
                        icono: Icons.location_off_outlined,
                        titulo: 'Sin bicicleteros',
                        detalle: 'Los que agregues aparecerán aquí.',
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: bicicleteros.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _TarjetaBicicleteroAdmin(
                    bicicletero: bicicleteros[index],
                    onEditar: () =>
                        _abrirFormulario(bicicletero: bicicleteros[index]),
                    onEliminar: () => _eliminar(bicicleteros[index]),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _EncabezadoAdminBicicleteros extends StatelessWidget {
  const _EncabezadoAdminBicicleteros({required this.onCrear});

  final VoidCallback onCrear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bicicleteros',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: ColoresUbb.azulNoche,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Puntos de ingreso y retiro habilitados en el campus.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColoresUbb.textoSecundario,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ColoresUbb.azulApp,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onCrear,
            icon: const Icon(Icons.add_location_alt_outlined, size: 19),
            label: const Text('Bicicletero'),
          ),
        ],
      ),
    );
  }
}

class _TarjetaBicicleteroAdmin extends StatefulWidget {
  const _TarjetaBicicleteroAdmin({
    required this.bicicletero,
    required this.onEditar,
    required this.onEliminar,
  });

  final BicicleteroApp bicicletero;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  State<_TarjetaBicicleteroAdmin> createState() =>
      _TarjetaBicicleteroAdminState();
}

class _TarjetaBicicleteroAdminState extends State<_TarjetaBicicleteroAdmin> {
  bool gestionAbierta = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaBicicleteroApp(bicicletero: widget.bicicletero),
        const SizedBox(height: 8),
        _BotonGestionBicicletero(
          expandido: gestionAbierta,
          onTap: () => setState(() => gestionAbierta = !gestionAbierta),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: gestionAbierta
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: _PanelGestionBicicletero(
            onEditar: widget.onEditar,
            onEliminar: widget.onEliminar,
          ),
        ),
      ],
    );
  }
}

class _BotonGestionBicicletero extends StatelessWidget {
  const _BotonGestionBicicletero({
    required this.expandido,
    required this.onTap,
  });

  final bool expandido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ColoresUbb.bordeFuerte),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.settings_outlined, color: ColoresUbb.azulApp),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Gestionar bicicletero',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ColoresUbb.textoPrincipal,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Icon(
                  expandido
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: ColoresUbb.textoSecundario,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelGestionBicicletero extends StatelessWidget {
  const _PanelGestionBicicletero({
    required this.onEditar,
    required this.onEliminar,
  });

  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ColoresUbb.fondo,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ColoresUbb.borde),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onEditar,
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresUbb.azulApp,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Editar'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onEliminar,
                  style: FilledButton.styleFrom(
                    backgroundColor: ColoresUbb.rojoInstitucional,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Eliminar'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
