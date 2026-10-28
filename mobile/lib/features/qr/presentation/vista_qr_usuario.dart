import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/conexion_provider.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/servicios/ubicacion_servicio.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/qr/application/qr_usuario_vm.dart';
import 'package:ubbike/features/qr/data/qr_modelos.dart';
import 'package:ubbike/features/qr/presentation/panel_qr_usuario.dart';
import 'package:ubbike/features/qr/presentation/seleccion_bicicletero_qr.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/utilidades/cercania_bicicletero.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';

class VistaQrUsuario extends ConsumerStatefulWidget {
  const VistaQrUsuario({super.key, this.onVerHistorial});

  final VoidCallback? onVerHistorial;

  @override
  ConsumerState<VistaQrUsuario> createState() => _VistaQrUsuarioState();
}

class _VistaQrUsuarioState extends ConsumerState<VistaQrUsuario> {
  static const _segundosAntesDelHistorial = 4;
  static const _esperaAntesDeOfrecerNuevoQr = Duration(seconds: 60);
  static const _intervaloConsultaEstado = Duration(seconds: 4);

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
  EstadoQr? estadoQr;
  String? motivoQr;
  int segundosParaHistorial = 0;
  Timer? _temporizadorHistorial;
  Timer? _temporizadorEspera;
  Timer? _consultaEstado;
  bool esperaLarga = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _temporizadorHistorial?.cancel();
    _detenerEspera();
    super.dispose();
  }

  void _detenerEspera() {
    _temporizadorEspera?.cancel();
    _consultaEstado?.cancel();
  }

  Future<void> _sincronizarEstado() async {
    final qr = qrActual;
    if (qr == null || estadoQr?.esFinal == true) {
      return;
    }
    try {
      final evento = await vm.consultarEstado(qr.id);
      if (evento != null && evento.estado != estadoQr) {
        _alRecibirEventoQr(evento);
      }
    } catch (_) {}
  }

  void _alRecibirEventoQr(EventoQrApp? evento) {
    final qr = qrActual;
    if (!mounted || evento == null || qr == null || evento.qrId != qr.id) {
      return;
    }
    if (estadoQr?.esFinal == true) {
      return;
    }

    if (evento.estado == EstadoQr.liberado) {
      if (estadoQr != EstadoQr.escaneado) {
        return;
      }
      _detenerEspera();
      setState(() {
        estadoQr = null;
        motivoQr = null;
        esperaLarga = false;
      });
      context.mostrarInfo(
        'El guardia volverá a escanear tu QR. Si ya expiró, genera uno nuevo.',
      );
      return;
    }

    _detenerEspera();
    setState(() {
      estadoQr = evento.estado;
      motivoQr = evento.motivo;
      esperaLarga = false;
    });

    if (evento.estado == EstadoQr.escaneado) {
      _temporizadorEspera = Timer(_esperaAntesDeOfrecerNuevoQr, () {
        if (mounted) setState(() => esperaLarga = true);
      });
      _consultaEstado = Timer.periodic(
        _intervaloConsultaEstado,
        (_) => unawaited(_sincronizarEstado()),
      );
    } else if (evento.estado == EstadoQr.confirmado) {
      unawaited(HapticFeedback.mediumImpact());
      _iniciarCuentaAlHistorial();
    } else if (evento.estado == EstadoQr.denegado) {
      unawaited(HapticFeedback.heavyImpact());
    }
  }

  void _generarNuevoQr() {
    _detenerEspera();
    setState(() {
      estadoQr = null;
      motivoQr = null;
      esperaLarga = false;
    });
    unawaited(_generarQr());
  }

  void _iniciarCuentaAlHistorial() {
    _temporizadorHistorial?.cancel();
    setState(() => segundosParaHistorial = _segundosAntesDelHistorial);
    _temporizadorHistorial =
        Timer.periodic(const Duration(seconds: 1), (temporizador) {
      if (!mounted) {
        temporizador.cancel();
        return;
      }
      if (segundosParaHistorial <= 1) {
        _irAlHistorial();
        return;
      }
      setState(() => segundosParaHistorial--);
    });
  }

  void _irAlHistorial() {
    _temporizadorHistorial?.cancel();
    vm.notificarCambioBicicleta();
    widget.onVerHistorial?.call();
  }

  void _recargarConEstadoNuevo() {
    if (!mounted) {
      return;
    }

    _temporizadorHistorial?.cancel();
    _detenerEspera();
    setState(() {
      esperaLarga = false;
      cargandoDatos = true;
      qrActual = null;
      estadoQr = null;
      motivoQr = null;
    });
    _cargarDatos();
  }

  Future<void> _actualizarBicicleteros() async {
    try {
      final lista = await vm.listarBicicleteros();
      if (!mounted) return;
      final seleccionadoId = bicicleteroSeleccionado?.id;
      setState(() {
        bicicleteros = lista;
        bicicleteroSeleccionado =
            lista.where((item) => item.id == seleccionadoId).firstOrNull;
      });
    } catch (_) {}
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
    ref.listen<EventoQrApp?>(eventoQrProvider, (_, evento) {
      _alRecibirEventoQr(evento);
    });
    ref.listen<int>(bicicleterosVersionProvider, (_, __) {
      if (mounted && !cargandoDatos) unawaited(_actualizarBicicleteros());
    });
    ref.listen<EstadoConexion>(conexionProvider, (anterior, actual) {
      if (actual == EstadoConexion.conectado && anterior != actual) {
        unawaited(_sincronizarEstado());
      }
    });
    ref.listen<int>(bicicletasVersionProvider, (_, __) {
      if (estadoQr != EstadoQr.escaneado) _recargarConEstadoNuevo();
    });
    ref.listen<int>(movimientosVersionProvider, (_, __) {
      if (estadoQr == null) _recargarConEstadoNuevo();
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
    final enProceso = estadoQr != null;

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
                child: (debeSeleccionarBicicletero &&
                        !enProceso &&
                        sugerenciaCercania != null)
                    ? Padding(
                        key: const ValueKey('banner-sugerencia'),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: BannerSugerenciaBicicletero(
                          sugerencia: sugerenciaCercania!,
                          onAceptar: _aceptarSugerencia,
                          onDescartar: _descartarSugerencia,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('banner-vacio')),
              ),
            ),
            if (debeSeleccionarBicicletero && !enProceso)
              SelectorBicicleteroQr(
                bicicleteros: bicicleteros,
                bicicleteroSeleccionado: bicicleteroSeleccionado,
                onChanged: _cambiarBicicleteroSeleccionado,
              ),
            const SizedBox(height: 24),
            PanelQrUsuario(
              qr: qr,
              segundosRestantes: segundosRestantes,
              mostrarAyudaBicicletero: debeSeleccionarBicicletero,
              estado: estadoQr,
              motivo: motivoQr,
              segundosParaHistorial: segundosParaHistorial,
              onVerHistorial: _irAlHistorial,
              onIntentarDeNuevo: _generarNuevoQr,
              onGenerarNuevoEnEspera: esperaLarga ? _generarNuevoQr : null,
            ),
            const SizedBox(height: 32),
            if (!enProceso)
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
        setState(() {
          qrActual = qr;
          estadoQr = null;
          motivoQr = null;
        });
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
