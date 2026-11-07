import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/acceso/application/escaner_qr_vm.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:ubbike/features/acceso/presentation/dialogo_resultado_movimiento.dart';
import 'package:ubbike/features/acceso/presentation/formulario_qr_validado.dart';
import 'package:ubbike/features/acceso/presentation/panel_escaneo_guardia.dart';
import 'package:ubbike/features/acceso/presentation/hoja_denegacion_qr.dart';
import 'package:ubbike/shared/utilidades/foco.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';

class VistaEscanerQrGuardia extends ConsumerStatefulWidget {
  const VistaEscanerQrGuardia({super.key, this.onMovimientoRegistrado});

  final VoidCallback? onMovimientoRegistrado;

  @override
  ConsumerState<VistaEscanerQrGuardia> createState() =>
      _VistaEscanerQrGuardiaState();
}

class _VistaEscanerQrGuardiaState extends ConsumerState<VistaEscanerQrGuardia> {
  EscanerQrVm get vm => ref.read(escanerQrVmProvider);
  final claveFormularioQrValidado = GlobalKey<FormState>();
  final controladorComentario = TextEditingController();
  late MobileScannerController _controladorEscaner;
  int _sesionEscaner = 0;
  String? codigoDetectado;
  QrValidadoApp? qrLeido;
  bool cargando = false;
  bool escaneando = false;
  bool preparandoEscaner = false;
  bool confirmando = false;

  @override
  void initState() {
    super.initState();
    _controladorEscaner = _crearControladorEscaner();
  }

  @override
  void dispose() {
    controladorComentario.dispose();
    unawaited(
        _controladorEscaner.stop().whenComplete(_controladorEscaner.dispose));
    super.dispose();
  }

  MobileScannerController _crearControladorEscaner() {
    return MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  void _onDeteccion(BarcodeCapture captura) {
    if (cargando ||
        preparandoEscaner ||
        !escaneando ||
        codigoDetectado != null) {
      return;
    }
    final codigo = captura.barcodes.firstOrNull?.rawValue;
    if (codigo == null || codigo.isEmpty) return;
    setState(() {
      codigoDetectado = codigo;
      escaneando = false;
      cargando = true;
    });
    unawaited(_procesarQrDetectado(codigo));
  }

  void _alternarEscaneo() {
    unawaited(_cambiarEstadoEscaner());
  }

  Future<void> _cambiarEstadoEscaner() async {
    if (preparandoEscaner || cargando) {
      return;
    }

    if (escaneando) {
      await _detenerEscaner();
      return;
    }

    await _iniciarEscaner();
  }

  Future<void> _iniciarEscaner() async {
    setState(() {
      codigoDetectado = null;
      qrLeido = null;
      controladorComentario.clear();
      escaneando = true;
      preparandoEscaner = true;
      _sesionEscaner += 1;
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !escaneando) {
      return;
    }

    try {
      await _controladorEscaner.start();
      final error = _controladorEscaner.value.error;
      if (error != null) {
        await _manejarErrorEscaner(error);
        return;
      }

      if (mounted) {
        setState(() => preparandoEscaner = false);
      }
    } catch (_) {
      if (mounted) {
        await _manejarErrorEscaner(null);
      }
    }
  }

  void _limpiarLectura() {
    unawaited(_limpiarLecturaAsincrona());
  }

  Future<void> _limpiarLecturaAsincrona() async {
    await _detenerCamaraSilencioso();
    if (!mounted) {
      return;
    }

    setState(() {
      codigoDetectado = null;
      qrLeido = null;
      escaneando = false;
      preparandoEscaner = false;
      controladorComentario.clear();
    });
  }

  Future<void> _detenerEscaner() async {
    setState(() => preparandoEscaner = true);
    await _detenerCamaraSilencioso();
    if (!mounted) {
      return;
    }

    setState(() {
      escaneando = false;
      preparandoEscaner = false;
    });
  }

  Future<void> _detenerCamaraSilencioso() async {
    try {
      await _controladorEscaner.stop();
    } catch (_) {}
  }

  Future<void> _procesarQrDetectado(String codigo) async {
    await _detenerCamaraSilencioso();
    await _validarQr(codigo, cargandoActivo: true);
  }

  Future<void> _manejarErrorEscaner(MobileScannerException? error) async {
    final mensaje = mensajeErrorEscaner(error);
    await _detenerCamaraSilencioso();
    if (!mounted) {
      return;
    }

    setState(() {
      escaneando = false;
      preparandoEscaner = false;
    });
    context.mostrarError(mensaje);
  }

  void _reintentarEscaner() {
    unawaited(_reintentarEscanerAsincrono());
  }

  Future<void> _reintentarEscanerAsincrono() async {
    if (preparandoEscaner || cargando) {
      return;
    }

    await _detenerCamaraSilencioso();
    if (!mounted) {
      return;
    }

    setState(() {
      escaneando = false;
      preparandoEscaner = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      await _iniciarEscaner();
    }
  }

  @override
  Widget build(BuildContext context) {
    final qr = qrLeido;
    if (qr != null) {
      return ListView(
        children: [
          const SizedBox(height: 8),
          FormularioQrValidado(
            claveFormulario: claveFormularioQrValidado,
            qr: qr,
            controladorComentario: controladorComentario,
            onConfirmar: () => _confirmarQr(qr),
            onDenegar: () => _mostrarDenegacion(context, qr),
            onLeerOtro: () => _escanearNuevamente(qr),
            procesando: confirmando,
          ),
        ],
      );
    }

    return ListView(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 396,
          width: double.infinity,
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
              padding: const EdgeInsets.all(18),
              child: ContenidoPanelEscaneoGuardia(
                escaneando: escaneando,
                cargando: cargando,
                codigoDetectado: codigoDetectado != null &&
                    codigoDetectado!.trim().isNotEmpty,
                qrValidado: false,
                controller: _controladorEscaner,
                sesionEscaner: _sesionEscaner,
                onDeteccion: _onDeteccion,
                onReintentar: _reintentarEscaner,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: ColoresUbb.azulApp,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: cargando || preparandoEscaner ? null : _alternarEscaneo,
          child: Text(
            preparandoEscaner
                ? 'Preparando cámara'
                : escaneando
                    ? 'Detener escaneo'
                    : 'Escanear QR',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _validarQr(String? codigo, {bool cargandoActivo = false}) async {
    final token = (codigo ?? codigoDetectado)?.trim();
    if (token == null || token.isEmpty) {
      return;
    }

    if (!cargandoActivo) {
      setState(() => cargando = true);
    }

    try {
      final qr = await vm.validarQr(token);
      if (mounted) {
        setState(() {
          qrLeido = qr;
          controladorComentario.clear();
        });
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        setState(() {
          qrLeido = null;
          codigoDetectado = null;
          escaneando = false;
        });
        context.mostrarError(error.mensaje);
      }
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  Future<void> _confirmarQr(QrValidadoApp qr) async {
    soltarFoco();
    if (claveFormularioQrValidado.currentState?.validate() != true ||
        confirmando) {
      return;
    }

    setState(() => confirmando = true);
    try {
      final movimiento = await vm.confirmarQr(
        qr.token,
        comentario: controladorComentario.text.trim(),
      );
      if (mounted) {
        _limpiarLectura();
        unawaited(avisarMovimientoRegistrado(
          context,
          confirmado: true,
          esIngreso: movimiento.tipo == 'INGRESO',
          persona: qr.usuarioNombre,
          alTerminar: widget.onMovimientoRegistrado,
        ));
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError(mensajeSinConexion);
      }
    } finally {
      if (mounted) {
        setState(() => confirmando = false);
      }
    }
  }

  Future<void> _escanearNuevamente(QrValidadoApp qr) async {
    unawaited(vm.liberarQr(qr.token).catchError((Object _) {}));
    await _limpiarLecturaAsincrona();
    if (mounted) {
      await _iniciarEscaner();
    }
  }

  void _mostrarDenegacion(BuildContext context, QrValidadoApp qr) {
    soltarFoco();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => HojaDenegacion(
        esIngreso: qr.tipo == 'INGRESO',
        onConfirmar: (motivo) => _confirmarDenegacion(qr, motivo),
      ),
    );
  }

  Future<String?> _confirmarDenegacion(QrValidadoApp qr, String motivo) async {
    try {
      await vm.denegarQr(token: qr.token, motivo: motivo);
      if (mounted) {
        _limpiarLectura();
        unawaited(avisarMovimientoRegistrado(
          context,
          confirmado: false,
          esIngreso: qr.tipo == 'INGRESO',
          persona: qr.usuarioNombre,
          alTerminar: widget.onMovimientoRegistrado,
        ));
      }
      return null;
    } on ExcepcionApi catch (error) {
      return error.mensaje;
    } catch (_) {
      return mensajeSinConexion;
    }
  }
}
