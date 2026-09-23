import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ubbike/features/bicicletas/application/bicicletas_vm.dart';
import 'package:ubbike/features/qr/application/qr_usuario_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/qr/data/qr_modelos.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/servicios/ubicacion_servicio.dart';
import 'package:ubbike/shared/utils/cercania_bicicletero.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/features/qr/presentation/qr_widgets.dart';
import 'package:ubbike/features/bicicletas/presentation/formulario_bicicleta_usuario.dart';

class VistaQrUsuario extends ConsumerStatefulWidget {
  const VistaQrUsuario({super.key});

  @override
  ConsumerState<VistaQrUsuario> createState() => _VistaQrUsuarioState();
}

class _VistaQrUsuarioState extends ConsumerState<VistaQrUsuario> {
  QrUsuarioVm get vm => ref.read(qrUsuarioVmProvider);
  final UbicacionServicio ubicacionServicio = const UbicacionServicio();
  QrTemporalApp? qrActual;
  BicicletaApp? bicicletaActiva;
  BicicleteroApp? bicicleteroSeleccionado;
  List<BicicleteroApp> bicicleteros = [];
  SugerenciaBicicletero? sugerenciaCercania;
  bool cargandoDatos = true;
  bool generando = false;
  int _generacionQr = 0;
  int _cargaEnCurso = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final carga = ++_cargaEnCurso;

    try {
      final resultados = await Future.wait([
        vm.obtenerActiva(),
        vm.listarBicicleteros(),
      ]);

      if (mounted) {
        final bicicleta = resultados[0] as BicicletaApp?;
        final listaBicicleteros = resultados[1] as List<BicicleteroApp>;
        setState(() {
          bicicletaActiva = bicicleta;
          bicicleteros = listaBicicleteros;
          bicicleteroSeleccionado = null;
          sugerenciaCercania = null;
          cargandoDatos = false;
        });

        final debeSugerir = bicicleta?.dentroBicicletero != true;
        if (debeSugerir) {
          unawaited(_buscarSugerenciaCercania(listaBicicleteros, carga));
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => cargandoDatos = false);
      }
    }
  }

  Future<void> _buscarSugerenciaCercania(
    List<BicicleteroApp> listaBicicleteros,
    int carga,
  ) async {
    final posicion = await ubicacionServicio.obtenerPosicionActual();
    if (posicion == null || !mounted || carga != _cargaEnCurso) {
      return;
    }

    final sugerencia = bicicleteroMasCercano(
      bicicleteros: listaBicicleteros,
      latitudUsuario: posicion.latitude,
      longitudUsuario: posicion.longitude,
    );

    if (sugerencia == null ||
        sugerencia.bicicletero.id == bicicleteroSeleccionado?.id) {
      return;
    }

    if (mounted) {
      setState(() => sugerenciaCercania = sugerencia);
    }
  }

  void _aceptarSugerencia() {
    final sugerencia = sugerenciaCercania;
    if (sugerencia == null) {
      return;
    }
    setState(() {
      bicicleteroSeleccionado = sugerencia.bicicletero;
      sugerenciaCercania = null;
    });
  }

  void _descartarSugerencia() {
    setState(() => sugerenciaCercania = null);
  }

  void _cambiarBicicleteroSeleccionado(BicicleteroApp? valor) {
    setState(() {
      bicicleteroSeleccionado = valor;
      sugerenciaCercania = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(bicicletasVersionProvider, (_, __) {
      if (!mounted) {
        return;
      }

      setState(() {
        cargandoDatos = true;
        qrActual = null;
      });
      _cargarDatos();
    });

    final qr = qrActual;
    final segundosRestantes = qr == null
        ? 0
        : qr.expiraEn
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, qr.duracionSegundos);
    final bicicleta = bicicletaActiva;
    final tipoOperacion =
        bicicleta?.dentroBicicletero == true ? 'RETIRO' : 'INGRESO';
    final debeSeleccionarBicicletero = tipoOperacion == 'INGRESO';

    return RefreshIndicator(
      onRefresh: () => _cargarDatos(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 8),
          if (cargandoDatos)
            const Center(child: CircularProgressIndicator())
          else if (bicicleta == null)
            const EstadoLista(
              icono: Icons.pedal_bike,
              titulo: 'Sin bicicleta activa',
              detalle: 'Activa una bicicleta antes de generar QR.',
            )
          else ...[
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child:
                    (debeSeleccionarBicicletero && sugerenciaCercania != null)
                        ? Padding(
                            key: const ValueKey('banner-sugerencia'),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BannerSugerenciaBicicletero(
                              sugerencia: sugerenciaCercania!,
                              onAceptar: _aceptarSugerencia,
                              onDescartar: _descartarSugerencia,
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('banner-vacio')),
              ),
            ),
            if (debeSeleccionarBicicletero)
              _SelectorBicicleteroQr(
                bicicleteros: bicicleteros,
                bicicleteroSeleccionado: bicicleteroSeleccionado,
                onChanged: _cambiarBicicleteroSeleccionado,
              ),
            const SizedBox(height: 24),
            _PanelQrUsuario(
              qr: qr,
              segundosRestantes: segundosRestantes,
              mostrarAyudaBicicletero: debeSeleccionarBicicletero,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: ColoresUbb.azulApp,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: generando ||
                      cargandoDatos ||
                      (debeSeleccionarBicicletero &&
                          bicicleteroSeleccionado == null)
                  ? null
                  : _generarQr,
              icon: generando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh, color: Colors.white),
              label: Text(
                qr == null || segundosRestantes == 0
                    ? 'Generar QR'
                    : 'Regenerar QR',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generarQr() async {
    setState(() => generando = true);

    try {
      final tipo =
          bicicletaActiva?.dentroBicicletero == true ? 'RETIRO' : 'INGRESO';
      final qr = await vm.generar(
        bicicleteroId: tipo == 'INGRESO' ? bicicleteroSeleccionado?.id : null,
      );

      if (mounted) {
        _generacionQr++;
        setState(() => qrActual = qr);
        _programarActualizacion(_generacionQr);
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } finally {
      if (mounted) {
        setState(() => generando = false);
      }
    }
  }

  void _programarActualizacion(int generacion) {
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted || qrActual == null || generacion != _generacionQr) {
        return;
      }

      setState(() {});

      if (qrActual!.expiraEn.isAfter(DateTime.now())) {
        _programarActualizacion(generacion);
      }
    });
  }
}

class _BannerSugerenciaBicicletero extends StatelessWidget {
  const _BannerSugerenciaBicicletero({
    required this.sugerencia,
    required this.onAceptar,
    required this.onDescartar,
  });

  final SugerenciaBicicletero sugerencia;
  final VoidCallback onAceptar;
  final VoidCallback onDescartar;

  String get _distanciaFormateada {
    final metros = sugerencia.distanciaMetros;
    return metros < 1000
        ? '${metros.round()} m'
        : '${(metros / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresUbb.azulApp.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresUbb.azulApp.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.near_me_outlined, color: ColoresUbb.azulApp),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estás cerca de ${sugerencia.bicicletero.nombre}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: ColoresUbb.azulNoche,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'A $_distanciaFormateada de tu ubicación. ¿Usar este bicicletero?',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColoresUbb.textoSecundario,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColoresUbb.azulApp,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: onAceptar,
                      child: const Text('Aceptar'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onDescartar,
                      child: const Text('Ahora no'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorBicicleteroQr extends StatelessWidget {
  const _SelectorBicicleteroQr({
    required this.bicicleteros,
    required this.bicicleteroSeleccionado,
    required this.onChanged,
  });

  final List<BicicleteroApp> bicicleteros;
  final BicicleteroApp? bicicleteroSeleccionado;
  final ValueChanged<BicicleteroApp?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seleccione el bicicletero a utilizar',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ColoresUbb.azulNoche,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return DropdownAnclado<BicicleteroApp>(
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              menuMaxHeight: 300,
              value: bicicleteroSeleccionado,
              decoration: decoracionCampoFormularioBicicleta(
                labelText: 'Bicicletero',
                prefixIcon: const Icon(
                  Icons.location_on_outlined,
                  color: ColoresUbb.azulApp,
                ),
              ),
              dropdownColor: Colors.white,
              items: bicicleteros
                  .map(
                    (bicicletero) => DropdownMenuItem(
                      value: bicicletero,
                      enabled: bicicletero.cuposDisponibles > 0,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${bicicletero.nombre} (${bicicletero.cuposDisponibles} cupos)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                color: bicicletero.cuposDisponibles > 0
                                    ? null
                                    : ColoresUbb.textoSecundario,
                              ),
                            ),
                          ),
                          if (bicicletero.cuposDisponibles == 0)
                            const Icon(
                              Icons.block_outlined,
                              size: 16,
                              color: ColoresUbb.rojoInstitucional,
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            );
          },
        ),
      ],
    );
  }
}

class _PanelQrUsuario extends StatelessWidget {
  const _PanelQrUsuario({
    required this.qr,
    required this.segundosRestantes,
    required this.mostrarAyudaBicicletero,
  });

  final QrTemporalApp? qr;
  final int segundosRestantes;
  final bool mostrarAyudaBicicletero;

  @override
  Widget build(BuildContext context) {
    final qrActual = qr;

    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 396),
        child: Card(
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.grey.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: qrActual == null
                  ? _QrPlaceholder(
                      mostrarAyudaBicicletero: mostrarAyudaBicicletero,
                    )
                  : _QrActivo(
                      token: qrActual.token,
                      segundosRestantes: segundosRestantes,
                      duracionTotal: qrActual.duracionSegundos,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder({required this.mostrarAyudaBicicletero});

  final bool mostrarAyudaBicicletero;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('qr-placeholder'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColoresUbb.azulApp.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_2,
              color: ColoresUbb.azulApp,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'QR no generado',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (mostrarAyudaBicicletero) ...[
            const SizedBox(height: 8),
            Text(
              'Selecciona el bicicletero y genera el QR.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColoresUbb.textoSecundario,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QrActivo extends StatelessWidget {
  const _QrActivo({
    required this.token,
    required this.segundosRestantes,
    required this.duracionTotal,
  });

  final String token;
  final int segundosRestantes;
  final int duracionTotal;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('qr-activo'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        QrTemporal(
          token: token,
          segundosRestantes: segundosRestantes,
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: duracionTotal > 0
                ? (segundosRestantes / duracionTotal).clamp(0.0, 1.0)
                : 0,
            minHeight: 6,
            backgroundColor: ColoresUbb.bordeFuerte,
            valueColor: AlwaysStoppedAnimation(
              segundosRestantes > 5
                  ? ColoresUbb.azulApp
                  : ColoresUbb.rojoInstitucional,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ChipEstado(
          texto: segundosRestantes > 0
              ? 'Expira en $segundosRestantes s'
              : 'QR expirado',
          color: segundosRestantes > 0
              ? ColoresUbb.azulApp
              : ColoresUbb.rojoInstitucional,
        ),
      ],
    );
  }
}
