import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';

String mensajeErrorEscaner(MobileScannerException? error) {
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

class ContenidoPanelEscaneoGuardia extends StatelessWidget {
  const ContenidoPanelEscaneoGuardia({
    super.key,
    required this.escaneando,
    required this.cargando,
    required this.codigoDetectado,
    required this.qrValidado,
    required this.controller,
    required this.sesionEscaner,
    required this.onDeteccion,
    required this.onReintentar,
  });

  final bool escaneando;
  final bool cargando;
  final bool codigoDetectado;
  final bool qrValidado;
  final MobileScannerController controller;
  final int sesionEscaner;
  final void Function(BarcodeCapture captura) onDeteccion;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    if (escaneando) {
      return ClipRRect(
        key: ValueKey('camara-activa-$sesionEscaner'),
        borderRadius: BorderRadius.circular(18),
        child: MobileScanner(
          controller: controller,
          onDetect: onDeteccion,
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
      detalle = 'Abriendo el formulario de validación.';
    } else {
      icono = Icons.qr_code_2;
      color = ColoresUbb.azulApp;
      titulo = 'QR no escaneado';
      detalle = 'Presiona Escanear QR y apunta al código del usuario.';
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
                mensajeErrorEscaner(error),
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
