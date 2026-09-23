import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/features/acceso/application/escaner_qr_vm.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/features/bicicletas/presentation/formulario_bicicleta_usuario.dart';

class VistaEscanerQrGuardia extends ConsumerStatefulWidget {
  const VistaEscanerQrGuardia({super.key, this.onMovimientoRegistrado});

  final VoidCallback? onMovimientoRegistrado;

  @override
  ConsumerState<VistaEscanerQrGuardia> createState() =>
      _VistaEscanerQrGuardiaState();
}

class _VistaEscanerQrGuardiaState extends ConsumerState<VistaEscanerQrGuardia> {
  EscanerQrVm get vm => ref.read(escanerQrVmProvider);
  final formKeyQrValidado = GlobalKey<FormState>();
  final comentarioController = TextEditingController();
  late MobileScannerController _scannerController;
  int _sesionEscaner = 0;
  String? codigoDetectado;
  QrValidadoApp? qrLeido;
  bool cargando = false;
  bool escaneando = false;
  bool preparandoEscaner = false;

  @override
  void initState() {
    super.initState();
    _scannerController = _crearScannerController();
  }

  @override
  void dispose() {
    comentarioController.dispose();
    unawaited(
        _scannerController.stop().whenComplete(_scannerController.dispose));
    super.dispose();
  }

  MobileScannerController _crearScannerController() {
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

  void _toggleEscanear() {
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
      comentarioController.clear();
      escaneando = true;
      preparandoEscaner = true;
      _sesionEscaner += 1;
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !escaneando) {
      return;
    }

    try {
      await _scannerController.start();
      final error = _scannerController.value.error;
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
    unawaited(_limpiarLecturaAsync());
  }

  Future<void> _limpiarLecturaAsync() async {
    await _detenerCamaraSilencioso();
    if (!mounted) {
      return;
    }

    setState(() {
      codigoDetectado = null;
      qrLeido = null;
      escaneando = false;
      preparandoEscaner = false;
      comentarioController.clear();
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
      await _scannerController.stop();
    } catch (_) {}
  }

  Future<void> _procesarQrDetectado(String codigo) async {
    await _detenerCamaraSilencioso();
    await _validarQr(codigo, cargandoActivo: true);
  }

  Future<void> _manejarErrorEscaner(MobileScannerException? error) async {
    final mensaje = _mensajeErrorEscaner(error);
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
    unawaited(_reintentarEscanerAsync());
  }

  Future<void> _reintentarEscanerAsync() async {
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
          _FormularioQrValidado(
            formKey: formKeyQrValidado,
            qr: qr,
            comentarioController: comentarioController,
            onConfirmar: () => _confirmarQr(qr),
            onDenegar: () => _mostrarDenegacion(context, qr),
            onLeerOtro: _limpiarLectura,
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
              child: _ContenidoPanelEscaneoGuardia(
                escaneando: escaneando,
                cargando: cargando,
                codigoDetectado: codigoDetectado != null &&
                    codigoDetectado!.trim().isNotEmpty,
                qrValidado: false,
                controller: _scannerController,
                sesionEscaner: _sesionEscaner,
                onDetect: _onDeteccion,
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
          onPressed: cargando || preparandoEscaner ? null : _toggleEscanear,
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
          comentarioController.clear();
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
    if (formKeyQrValidado.currentState?.validate() != true) {
      return;
    }

    try {
      final movimiento = await vm.confirmarQr(
        qr.token,
        comentario: comentarioController.text.trim(),
      );
      if (mounted) {
        _limpiarLectura();
        context.mostrarExito(
          '${movimiento.tipo == 'INGRESO' ? 'Ingreso' : 'Retiro'} confirmado',
        );
        widget.onMovimientoRegistrado?.call();
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    }
  }

  void _mostrarDenegacion(BuildContext context, QrValidadoApp qr) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SheetDenegacion(
        onConfirmar: (motivo) => _confirmarDenegacion(qr, motivo),
      ),
    );
  }

  Future<bool> _confirmarDenegacion(QrValidadoApp qr, String motivo) async {
    try {
      await vm.denegarQr(token: qr.token, motivo: motivo);
      if (mounted) {
        _limpiarLectura();
        if (context.mounted) {
          context.mostrarInfo('Operación denegada');
        }
        widget.onMovimientoRegistrado?.call();
      }
      return true;
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
      return false;
    } catch (_) {
      if (mounted) {
        context.mostrarError('No se pudo conectar con el backend');
      }
      return false;
    }
  }
}

String _mensajeErrorEscaner(MobileScannerException? error) {
  return switch (error?.errorCode) {
    MobileScannerErrorCode.permissionDenied =>
      'Permite el uso de la cámara para escanear QR.',
    MobileScannerErrorCode.unsupported =>
      'Este dispositivo no permite escanear QR desde la cámara.',
    MobileScannerErrorCode.controllerAlreadyInitialized =>
      'La cámara todavía se está liberando. Intenta nuevamente en unos segundos.',
    MobileScannerErrorCode.controllerDisposed ||
    MobileScannerErrorCode.controllerUninitialized =>
      'No se pudo preparar la cámara. Intenta abrir el escáner nuevamente.',
    _ =>
      'No se pudo iniciar la cámara. Cierra el escáner e intenta nuevamente.',
  };
}

class SheetDenegacion extends StatefulWidget {
  const SheetDenegacion({super.key, required this.onConfirmar});

  final Future<bool> Function(String motivo) onConfirmar;

  @override
  State<SheetDenegacion> createState() => _SheetDenegacionState();
}

class _SheetDenegacionState extends State<SheetDenegacion> {
  final formKeyDenegacion = GlobalKey<FormState>();
  final motivoController = TextEditingController();
  bool enviando = false;

  @override
  void dispose() {
    motivoController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (formKeyDenegacion.currentState?.validate() != true || enviando) {
      return;
    }
    setState(() => enviando = true);
    final ok = await widget.onConfirmar(motivoController.text.trim());
    if (!mounted) {
      return;
    }
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: formKeyDenegacion,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Motivo de denegación',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: motivoController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Indica el motivo',
                  alignLabelWithHint: true,
                ),
                validator: _validarMotivoDenegacionQrGuardia,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: enviando ? null : _enviar,
                icon: enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Registrar denegación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _validarComentarioQrGuardia(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.length > 600) {
    return 'Maximo 600 caracteres.';
  }
  return null;
}

String? _validarMotivoDenegacionQrGuardia(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa el motivo.';
  }
  if (texto.length < 3) {
    return 'Debe tener al menos 3 caracteres.';
  }
  if (texto.length > 600) {
    return 'Maximo 600 caracteres.';
  }
  return null;
}

class _FormularioQrValidado extends StatelessWidget {
  const _FormularioQrValidado({
    required this.formKey,
    required this.qr,
    required this.comentarioController,
    required this.onConfirmar,
    required this.onDenegar,
    required this.onLeerOtro,
  });

  final GlobalKey<FormState> formKey;
  final QrValidadoApp qr;
  final TextEditingController comentarioController;
  final VoidCallback onConfirmar;
  final VoidCallback onDenegar;
  final VoidCallback onLeerOtro;

  @override
  Widget build(BuildContext context) {
    final esIngreso = qr.tipo == 'INGRESO';
    final color = esIngreso ? ColoresUbb.exito : ColoresUbb.azulApp;
    final accion = esIngreso ? 'Ingreso' : 'Retiro';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      esIngreso ? Icons.login : Icons.logout,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QR válido',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        Text(
                          'Autorizar $accion',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: ColoresUbb.azulNoche,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  ChipEstado(texto: accion, color: color),
                ],
              ),
              const SizedBox(height: 14),
              const _TituloFormularioQr(
                icono: Icons.person_outline,
                texto: 'Información del usuario',
              ),
              const SizedBox(height: 10),
              _CampoLecturaQr(
                label: 'Nombre',
                valor: qr.usuarioNombre,
              ),
              const SizedBox(height: 10),
              _CampoLecturaQr(
                label: 'Correo',
                valor: qr.usuarioCorreo,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CampoLecturaQr(
                      label: 'RUT',
                      valor: qr.usuarioRut ?? 'Sin RUT',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CampoLecturaQr(
                      label: 'Bicicletero',
                      valor: qr.bicicleteroNombre ?? 'Asignación guardia',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _TituloFormularioQr(
                icono: Icons.pedal_bike_outlined,
                texto: 'Datos de bicicleta',
              ),
              const SizedBox(height: 10),
              _CampoLecturaQr(
                label: 'Descripción',
                valor: qr.bicicletaDescripcion,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CampoLecturaQr(
                      label: 'Marca',
                      valor: textoNoVacio(qr.bicicletaMarca, 'Sin marca'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CampoLecturaQr(
                      label: 'Modelo',
                      valor: textoNoVacio(qr.bicicletaModelo, 'Sin modelo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CampoLecturaQr(
                      label: 'Color',
                      valor: textoNoVacio(qr.bicicletaColor, 'Sin color'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CampoLecturaQr(
                      label: 'Aro',
                      valor: textoNoVacio(qr.bicicletaAro, 'Sin aro'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _CampoLecturaQr(
                label: 'Número de serie',
                valor: textoNoVacio(qr.bicicletaNumeroSerie, 'Sin serie'),
              ),
              const SizedBox(height: 12),
              SelectorFotoBicicleta(
                fotoDataUrl: qr.bicicletaFotoUrl,
                onCamara: () {},
                onGaleria: () {},
                onQuitar: null,
                mostrarAcciones: false,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: comentarioController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Comentario opcional del guardia',
                  hintText: 'Ej: Usuario posee U-Lock',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                ),
                validator: _validarComentarioQrGuardia,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirmar,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Confirmar ${accion.toLowerCase()}'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColoresUbb.rojoInstitucional,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onDenegar,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Denegar ${accion.toLowerCase()}'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: onLeerOtro,
                icon: const Icon(Icons.qr_code_scanner_outlined),
                label: const Text('Escanear nuevamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String textoNoVacio(String? valor, String respaldo) {
    final texto = valor?.trim();
    return texto == null || texto.isEmpty ? respaldo : texto;
  }
}

class _TituloFormularioQr extends StatelessWidget {
  const _TituloFormularioQr({
    required this.icono,
    required this.texto,
  });

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, color: ColoresUbb.azulApp, size: 18),
        const SizedBox(width: 8),
        Text(
          texto,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: ColoresUbb.azulNoche,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _CampoLecturaQr extends StatelessWidget {
  const _CampoLecturaQr({
    required this.label,
    required this.valor,
  });

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('$label-$valor'),
      initialValue: valor,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
    );
  }
}

class _ContenidoPanelEscaneoGuardia extends StatelessWidget {
  const _ContenidoPanelEscaneoGuardia({
    required this.escaneando,
    required this.cargando,
    required this.codigoDetectado,
    required this.qrValidado,
    required this.controller,
    required this.sesionEscaner,
    required this.onDetect,
    required this.onReintentar,
  });

  final bool escaneando;
  final bool cargando;
  final bool codigoDetectado;
  final bool qrValidado;
  final MobileScannerController controller;
  final int sesionEscaner;
  final void Function(BarcodeCapture captura) onDetect;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    if (escaneando) {
      return ClipRRect(
        key: ValueKey('camara-activa-$sesionEscaner'),
        borderRadius: BorderRadius.circular(18),
        child: MobileScanner(
          controller: controller,
          onDetect: onDetect,
          placeholderBuilder: (context, child) =>
              const _EstadoCamaraQr(mensaje: 'Activando cámara...'),
          errorBuilder: (context, error, child) => _ErrorEscanerQr(
            error: error,
            onReintentar: onReintentar,
          ),
        ),
      );
    }

    final IconData icono;
    final Color color;
    final String titulo;
    final String detalle;

    if (cargando) {
      icono = Icons.hourglass_empty_outlined;
      color = ColoresUbb.azulApp;
      titulo = 'Validando QR';
      detalle = 'Estamos revisando el movimiento detectado.';
    } else if (qrValidado) {
      icono = Icons.verified_outlined;
      color = ColoresUbb.exito;
      titulo = 'QR validado';
      detalle = 'Revisa los datos y confirma o deniega el movimiento.';
    } else if (codigoDetectado) {
      icono = Icons.qr_code_scanner;
      color = ColoresUbb.exito;
      titulo = 'QR detectado';
      detalle = 'Abriendo el formulario de validacion.';
    } else {
      icono = Icons.qr_code_2;
      color = ColoresUbb.azulApp;
      titulo = 'QR no escaneado';
      detalle = 'Presiona Escanear QR y apunta al codigo del usuario.';
    }

    return Center(
      key: ValueKey(titulo),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: cargando
                ? const SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Icon(
                    icono,
                    color: color,
                    size: 42,
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColoresUbb.textoSecundario,
                ),
          ),
        ],
      ),
    );
  }
}

class _EstadoCamaraQr extends StatelessWidget {
  const _EstadoCamaraQr({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              mensaje,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorEscanerQr extends StatelessWidget {
  const _ErrorEscanerQr({
    required this.error,
    required this.onReintentar,
  });

  final MobileScannerException error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                _mensajeErrorEscaner(error),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
