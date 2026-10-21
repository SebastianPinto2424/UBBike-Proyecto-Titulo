import 'package:flutter/material.dart';

class VisorFoto extends StatefulWidget {
  const VisorFoto({super.key, required this.imagen});

  final Widget imagen;

  @override
  State<VisorFoto> createState() => _VisorFotoState();
}

class _VisorFotoState extends State<VisorFoto> {
  static const _zoomDobleToque = 2.5;

  final _transformacion = TransformationController();
  Offset _ultimoToque = Offset.zero;

  @override
  void dispose() {
    _transformacion.dispose();
    super.dispose();
  }

  void _alternarZoom() {
    if (_transformacion.value != Matrix4.identity()) {
      _transformacion.value = Matrix4.identity();
      return;
    }
    final desplazamiento = _ultimoToque * (1 - _zoomDobleToque);
    _transformacion.value =
        Matrix4.diagonal3Values(_zoomDobleToque, _zoomDobleToque, 1)
          ..setTranslationRaw(desplazamiento.dx, desplazamiento.dy, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onDoubleTapDown: (detalles) =>
                _ultimoToque = detalles.localPosition,
            onDoubleTap: _alternarZoom,
            child: InteractiveViewer(
              transformationController: _transformacion,
              minScale: 1,
              maxScale: 5,
              child: SizedBox.expand(child: widget.imagen),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
