import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/utilidades/auto_refresco.dart';
import 'package:ubbike/shared/widgets/dialogo_eliminar.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/vista_con_pestanas.dart';
import 'package:ubbike/features/bicicletas/presentation/bicicletas_widgets.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/features/bicicletas/presentation/formulario_bicicleta_usuario.dart';
import 'package:ubbike/features/bicicletas/application/bicicletas_vm.dart';
import 'package:ubbike/shared/widgets/boton_registrar_compacto.dart';

class VistaBicicletas extends ConsumerStatefulWidget {
  const VistaBicicletas({
    super.key,
    required this.vistaMovimientos,
    this.initialIndex = 0,
  });

  final Widget vistaMovimientos;

  final int initialIndex;

  @override
  ConsumerState<VistaBicicletas> createState() => _VistaBicicletasState();
}

class _VistaBicicletasState extends ConsumerState<VistaBicicletas>
    with AutoRefrescoMixin {
  BicicletasVm get vm => ref.read(bicicletasVmProvider);
  late Future<List<BicicletaApp>> futuroBicicletas;
  List<BicicletaApp>? _ultimoDato;

  @override
  void initState() {
    super.initState();
    futuroBicicletas = vm.listar();
    iniciarAutoRefresco();
  }

  @override
  Future<void> refrescar() async {
    if (mounted) {
      _recargar();
    }
  }

  void _recargar() {
    setState(() {
      futuroBicicletas = vm.listar();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(movimientosVersionProvider, (_, __) {
      if (mounted) _recargar();
    });

    return VistaConPestanas(
      initialIndex: widget.initialIndex,
      pestanas: [
        pestanaCompacta(Icons.pedal_bike_outlined, 'Bicicletas'),
        pestanaCompacta(Icons.manage_search_outlined, 'Movimientos'),
      ],
      vistas: [
        _vistaMisBicicletas(),
        widget.vistaMovimientos,
      ],
    );
  }

  Widget _vistaMisBicicletas() {
    return FutureBuilder<List<BicicletaApp>>(
      future: futuroBicicletas,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _ultimoDato = snapshot.data;
        }
        final snapshotEfectivo =
            snapshot.connectionState == ConnectionState.waiting &&
                    _ultimoDato != null
                ? AsyncSnapshot<List<BicicletaApp>>.withData(
                    ConnectionState.done, _ultimoDato!)
                : snapshot;
        final bicicletas = snapshotEfectivo.data ?? [];
        final mostrarBotonEncabezado =
            snapshotEfectivo.hasData && bicicletas.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _EncabezadoBicicletas(
              mostrarBoton: mostrarBotonEncabezado,
              onRegistrar: _mostrarFormularioBicicleta,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _recargar(),
                child: _ContenidoBicicletas(
                  snapshot: snapshotEfectivo,
                  onRegistrar: _mostrarFormularioBicicleta,
                  onEditar: (bicicleta) => _mostrarFormularioBicicleta(
                    bicicleta: bicicleta,
                  ),
                  onEliminar: _eliminarBicicleta,
                  onCambiarActiva: _cambiarEstadoActivoBicicleta,
                  onReintentar: _recargar,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cambiarEstadoActivoBicicleta(
    BicicletaApp bicicleta,
    bool activa,
  ) async {
    if (bicicleta.activa == activa) {
      return;
    }

    try {
      if (activa) {
        await vm.activar(bicicleta.id);
      } else {
        await vm.desactivar(bicicleta.id);
      }
      _recargar();
      if (mounted) {
        context.mostrarExito(
          activa
              ? '${bicicleta.descripcion} activada'
              : '${bicicleta.descripcion} inactiva',
        );
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    }
  }

  Future<void> _eliminarBicicleta(BicicletaApp bicicleta) async {
    final confirmar = await confirmarEliminacion(
      context,
      titulo: 'Eliminar bicicleta',
      nombre: bicicleta.descripcion,
      consecuencia:
          'Dejará de aparecer en tu lista y se borrará su foto. El historial de ingresos y retiros se conserva.',
    );

    if (!confirmar || !mounted) {
      return;
    }

    try {
      await vm.eliminar(bicicleta.id);
      _recargar();
      if (mounted) {
        context.mostrarExito('Bicicleta eliminada');
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    }
  }

  Future<void> _mostrarFormularioBicicleta({BicicletaApp? bicicleta}) async {
    final guardo = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (_) => HojaFormularioBicicleta(
        bicicleta: bicicleta,
      ),
    );

    if (guardo == true && mounted) {
      _recargar();
      context.mostrarExito(
        bicicleta == null
            ? 'Bicicleta registrada correctamente'
            : 'Datos editados correctamente',
      );
    }
  }
}

class _EncabezadoBicicletas extends StatelessWidget {
  const _EncabezadoBicicletas({
    required this.mostrarBoton,
    required this.onRegistrar,
  });

  final bool mostrarBoton;
  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: TituloApartado(titulo: 'Mis bicicletas')),
        if (mostrarBoton) ...[
          const SizedBox(width: 12),
          BotonRegistrarCompacto(
            texto: 'Registrar',
            onPressed: onRegistrar,
          ),
        ],
      ],
    );
  }
}

class _ContenidoBicicletas extends StatelessWidget {
  const _ContenidoBicicletas({
    required this.snapshot,
    required this.onRegistrar,
    required this.onEditar,
    required this.onEliminar,
    required this.onCambiarActiva,
    required this.onReintentar,
  });

  final AsyncSnapshot<List<BicicletaApp>> snapshot;
  final VoidCallback onRegistrar;
  final ValueChanged<BicicletaApp> onEditar;
  final ValueChanged<BicicletaApp> onEliminar;
  final void Function(BicicletaApp bicicleta, bool activa) onCambiarActiva;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 280,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (snapshot.hasError) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          TarjetaAccion(
            icono: Icons.cloud_off_outlined,
            titulo: 'No se pudieron cargar bicicletas',
            detalle: 'Revisa tu conexión y toca para reintentar.',
            color: ColoresUbb.rojoInstitucional,
            onTap: onReintentar,
          ),
        ],
      );
    }

    final bicicletas = snapshot.data ?? [];

    if (bicicletas.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 360,
            child: _EstadoVacioBicicletas(onRegistrar: onRegistrar),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ...bicicletas.map(
          (bicicleta) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TarjetaBicicletaUsuario(
              bicicleta: bicicleta,
              onEditar: () => onEditar(bicicleta),
              onEliminar: () => onEliminar(bicicleta),
              onCambiarActiva: (activa) => onCambiarActiva(bicicleta, activa),
            ),
          ),
        ),
      ],
    );
  }
}

class _EstadoVacioBicicletas extends StatelessWidget {
  const _EstadoVacioBicicletas({required this.onRegistrar});

  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.pedal_bike,
            size: 64,
            color: ColoresUbb.textoSecundario,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin bicicletas',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: ColoresUbb.textoSecundario),
          ),
          const SizedBox(height: 8),
          Text(
            'Registra tu primera bicicleta para usar el sistema.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: ColoresUbb.textoSecundario),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                backgroundColor: ColoresUbb.azulApp,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onRegistrar,
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Registrar bicicleta',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
