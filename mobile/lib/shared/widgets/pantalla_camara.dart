import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';

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
      if (!mounted) {
        await controlador.dispose();
        return;
      }
      setState(() {
        _controlador = controlador;
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_foto == null ? 'Tomar foto' : 'Revisar foto'),
      ),
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

    final controlador = _controlador;
    if (controlador == null || !controlador.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Column(
      children: [
        Expanded(child: Center(child: CameraPreview(controlador))),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Semantics(
            button: true,
            label: 'Tomar foto',
            child: GestureDetector(
              onTap: _capturar,
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                padding: const EdgeInsets.all(5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _capturando ? Colors.white54 : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  onPressed: onRepetir,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Repetir'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresUbb.azulApp,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onUsar,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Usar foto'),
                ),
              ),
            ],
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
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
              ),
              onPressed: onCerrar,
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }
}
