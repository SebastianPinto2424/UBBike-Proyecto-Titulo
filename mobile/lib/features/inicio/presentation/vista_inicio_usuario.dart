import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ubbike/features/inicio/application/inicio_usuario_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/utils/sesion_ui_utils.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/bicicletero_widgets.dart';
import 'package:ubbike/shared/widgets/encabezado_widgets.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';

class VistaInicioUsuario extends ConsumerStatefulWidget {
  const VistaInicioUsuario({super.key});

  @override
  ConsumerState<VistaInicioUsuario> createState() => _VistaInicioUsuarioState();
}

class _VistaInicioUsuarioState extends ConsumerState<VistaInicioUsuario> {
  InicioUsuarioVm get vm => ref.read(inicioUsuarioVmProvider);
  late Future<BicicletaApp?> futuroBicicletaActiva;
  late Future<List<BicicleteroApp>> futuroBicicleteros;
  BicicletaApp? ultimaBicicletaActiva;
  bool bicicletaActivaConsultada = false;
  List<BicicleteroApp>? ultimosBicicleteros;

  @override
  void initState() {
    super.initState();
    futuroBicicletaActiva = vm.obtenerActiva();
    futuroBicicleteros = vm.listarBicicleteros();
  }

  void _recargar() {
    setState(() {
      futuroBicicletaActiva = vm.obtenerActiva();
      futuroBicicleteros = vm.listarBicicleteros();
    });
  }

  @override
  Widget build(BuildContext context) {
    for (final version in [
      bicicletasVersionProvider,
      bicicleterosVersionProvider,
      movimientosVersionProvider,
    ]) {
      ref.listen<int>(version, (_, __) {
        if (mounted) _recargar();
      });
    }

    return ColoredBox(
      color: ColoresUbb.fondo,
      child: RefreshIndicator(
        color: ColoresUbb.azulApp,
        backgroundColor: ColoresUbb.fondo,
        onRefresh: () async => _recargar(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            FutureBuilder<BicicletaApp?>(
              future: futuroBicicletaActiva,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.waiting &&
                    !snapshot.hasError) {
                  ultimaBicicletaActiva = snapshot.data;
                  bicicletaActivaConsultada = true;
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _EncabezadoInicioUsuario(
                    bicicleta: ultimaBicicletaActiva,
                    cargando: !bicicletaActivaConsultada,
                  );
                }
                return _EncabezadoInicioUsuario(
                  bicicleta: snapshot.data,
                );
              },
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const TituloApartado(titulo: 'Uso de bicicleteros'),
                      const SizedBox(height: 10),
                      FutureBuilder<List<BicicleteroApp>>(
                        future: futuroBicicleteros,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            ultimosBicicleteros = snapshot.data;
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            final bicicleteros = ultimosBicicleteros;
                            if (bicicleteros == null) {
                              return const SizedBox.shrink();
                            }
                            return _ListaBicicleterosUsuario(
                                bicicleteros: bicicleteros);
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
                          return _ListaBicicleterosUsuario(
                              bicicleteros: bicicleteros);
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

class _ListaBicicleterosUsuario extends StatelessWidget {
  const _ListaBicicleterosUsuario({required this.bicicleteros});

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

class _EncabezadoInicioUsuario extends StatelessWidget {
  const _EncabezadoInicioUsuario({
    required this.bicicleta,
    this.cargando = false,
  });

  final BicicletaApp? bicicleta;

  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final bicicleta = this.bicicleta;
    final dentro = bicicleta?.dentroBicicletero ?? false;

    final titulo = cargando
        ? 'Cargando tu bicicleta…'
        : bicicleta == null
            ? 'Aún no registras una bicicleta'
            : dentro
                ? 'Bicicleta dentro del bicicletero'
                : 'Bicicleta fuera del bicicletero';

    final detalle = cargando
        ? 'Un momento, por favor.'
        : bicicleta == null
            ? 'Registra una bicicleta y márcala como activa.'
            : dentro
                ? '${bicicleta.descripcion} · ${bicicleta.bicicleteroActualNombre ?? 'Bicicletero no informado'}'
                : '${bicicleta.descripcion} · Genera tu QR para guardarla';

    final iconoEstado = cargando
        ? Icons.hourglass_empty_outlined
        : bicicleta == null
            ? Icons.pedal_bike_outlined
            : dentro
                ? Icons.lock_outline
                : Icons.lock_open_outlined;
    final colorEstado = bicicleta == null
        ? ColoresUbb.azulApp
        : dentro
            ? ColoresUbb.exito
            : ColoresUbb.turquesa;

    return PanelInicioOscuro(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EncabezadoSeccion(
            saludo: saludoActual(),
            nombre: nombreSesion(context, 'Usuario UBB'),
            sobreOscuro: true,
          ),
          const SizedBox(height: 16),
          EstadoInicioLiviano(
            icono: iconoEstado,
            color: colorEstado,
            titulo: titulo,
            detalle: detalle,
            sobreOscuro: true,
          ),
        ],
      ),
    );
  }
}
