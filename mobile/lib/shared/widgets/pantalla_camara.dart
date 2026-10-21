import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:ubbike/shared/widgets/botones_accion.dart';

Future<Uint8List?> tomarFotoEnApp(BuildContext context) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const PantallaCamara(),
    ),
  );
}

class PantallaCamara extends StatefulWidget {
  const PantallaCamara({super.key, this.buscarCamaras = availableCameras});

  final Future<List<CameraDescription>> Function() buscarCamaras;

  @override
  State<PantallaCamara> createState() => _PantallaCamaraState();
}

class _PantallaCamaraState extends State<PantallaCamara>
    with WidgetsBindingObserver {
  CameraController? _controlador;
  Uint8List? _foto;
  String? _error;
  bool _capturando = false;
  FlashMode _flash = FlashMode.auto;
  bool _flashDisponible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_iniciar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controlador?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    final controlador = _controlador;
    if (estado == AppLifecycleState.inactive && controlador != null) {
      _controlador = null;
      unawaited(controlador.dispose());
      if (mounted) setState(() {});
    } else if (estado == AppLifecycleState.resumed &&
        _controlador == null &&
        _foto == null) {
      unawaited(_iniciar());
    }
  }

  Future<void> _iniciar() async {
    try {
      final camaras = await widget.buscarCamaras();
      if (camaras.isEmpty) {
        if (mounted) {
          setState(() =>
              _error = 'Este dispositivo no tiene una cámara disponible.');
        }
        return;
      }
      final trasera = camaras.firstWhere(
        (camara) => camara.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );
      final controlador = CameraController(
        trasera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controlador.initialize();
      final flashDisponible = await _aplicarFlash(controlador, _flash);
      if (!mounted) {
        await controlador.dispose();
        return;
      }
      setState(() {
        _controlador = controlador;
        _flashDisponible = flashDisponible;
        _error = null;
      });
    } on CameraException catch (error) {
      if (mounted) {
        setState(() => _error = error.code.startsWith('CameraAccess')
            ? 'Permite el uso de la cámara para tomar la foto.'
            : 'No se pudo abrir la cámara. Intenta nuevamente.');
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'No se pudo abrir la cámara. Intenta nuevamente.');
      }
    }
  }

  Future<bool> _aplicarFlash(
      CameraController controlador, FlashMode modo) async {
    try {
      await controlador.setFlashMode(modo);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cambiarFlash() async {
    final controlador = _controlador;
    if (controlador == null) {
      return;
    }
    final siguiente = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    if (await _aplicarFlash(controlador, siguiente) && mounted) {
      setState(() => _flash = siguiente);
    }
  }

  Future<void> _capturar() async {
    final controlador = _controlador;
    if (controlador == null ||
        !controlador.value.isInitialized ||
        _capturando) {
      return;
    }
    setState(() => _capturando = true);
    try {
      final archivo = await controlador.takePicture();
      final bytes = await archivo.readAsBytes();
      if (mounted) setState(() => _foto = bytes);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'No se pudo tomar la foto. Intenta nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _capturando = false);
    }
  }

  void _repetir() {
    setState(() => _foto = null);
    if (_controlador == null) {
      unawaited(_iniciar());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _contenido()),
    );
  }

  Widget _contenido() {
    final foto = _foto;
    if (foto != null) {
      return _RevisionFoto(
        foto: foto,
        onRepetir: _repetir,
        onUsar: () => Navigator.of(context).pop(foto),
      );
    }

    final error = _error;
    if (error != null) {
      return _AvisoCamara(
        mensaje: error,
        onCerrar: () => Navigator.of(context).pop(),
      );
    }

    return _VistaCaptura(
      controlador: _controlador,
      capturando: _capturando,
      flash: _flashDisponible ? _flash : null,
      onCerrar: () => Navigator.of(context).pop(),
      onCambiarFlash: _cambiarFlash,
      onCapturar: _capturar,
    );
  }
}

class _VistaCaptura extends StatelessWidget {
  const _VistaCaptura({
    required this.controlador,
    required this.capturando,
    required this.flash,
    required this.onCerrar,
    required this.onCambiarFlash,
    required this.onCapturar,
  });

  final CameraController? controlador;
  final bool capturando;
  final FlashMode? flash;
  final VoidCallback onCerrar;
  final VoidCallback onCambiarFlash;
  final VoidCallback onCapturar;

  @override
  Widget build(BuildContext context) {
    final controlador = this.controlador;
    final listo = controlador != null && controlador.value.isInitialized;
    final flash = this.flash;

    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: listo
                ? CameraPreview(controlador)
                : const CircularProgressIndicator(color: Colors.white),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: _BotonFlotante(
            icono: Icons.close,
            tooltip: 'Cerrar',
            onPressed: onCerrar,
          ),
        ),
        if (flash != null)
          Positioned(
            top: 8,
            right: 8,
            child: _BotonFlotante(
              icono: switch (flash) {
                FlashMode.off => Icons.flash_off,
                FlashMode.auto => Icons.flash_auto,
                _ => Icons.flash_on,
              },
              tooltip: switch (flash) {
                FlashMode.off => 'Flash desactivado',
                FlashMode.auto => 'Flash automático',
                _ => 'Flash activado',
              },
              onPressed: onCambiarFlash,
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 28,
          child: Center(
            child: _Disparador(
              habilitado: listo && !capturando,
              capturando: capturando,
              onTap: onCapturar,
            ),
          ),
        ),
      ],
    );
  }
}

class _BotonFlotante extends StatelessWidget {
  const _BotonFlotante({
    required this.icono,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
      ),
      icon: Icon(icono),
    );
  }
}

class _Disparador extends StatelessWidget {
  const _Disparador({
    required this.habilitado,
    required this.capturando,
    required this.onTap,
  });

  final bool habilitado;
  final bool capturando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: habilitado,
      label: 'Tomar foto',
      child: GestureDetector(
        onTap: habilitado ? onTap : null,
        child: Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: habilitado ? Colors.white : Colors.white54,
            ),
            child: capturando
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black54,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _RevisionFoto extends StatelessWidget {
  const _RevisionFoto({
    required this.foto,
    required this.onRepetir,
    required this.onUsar,
  });

  final Uint8List foto;
  final VoidCallback onRepetir;
  final VoidCallback onUsar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: Center(child: Image.memory(foto, fit: BoxFit.contain))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: BotonesAccion.confirmacion(
            textoCancelar: 'Repetir',
            iconoCancelar: Icons.refresh,
            textoConfirmar: 'Usar foto',
            iconoConfirmar: Icons.check,
            onCancelar: onRepetir,
            onConfirmar: onUsar,
          ),
        ),
      ],
    );
  }
}

class _AvisoCamara extends StatelessWidget {
  const _AvisoCamara({required this.mensaje, required this.onCerrar});

  final String mensaje;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: onCerrar,
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
