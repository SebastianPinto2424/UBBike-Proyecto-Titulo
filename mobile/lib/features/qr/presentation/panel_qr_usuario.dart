import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/qr/data/qr_modelos.dart';
import 'package:ubbike/features/qr/presentation/qr_widgets.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';

class PanelQrUsuario extends StatelessWidget {
  const PanelQrUsuario({
    super.key,
    required this.qr,
    required this.segundosRestantes,
    required this.mostrarAyudaBicicletero,
    required this.estado,
    required this.motivo,
    required this.segundosParaHistorial,
    required this.onVerHistorial,
    required this.onIntentarDeNuevo,
    this.onGenerarNuevoEnEspera,
  });

  final QrTemporalApp? qr;
  final int segundosRestantes;
  final bool mostrarAyudaBicicletero;
  final EstadoQr? estado;
  final String? motivo;
  final int segundosParaHistorial;
  final VoidCallback onVerHistorial;
  final VoidCallback onIntentarDeNuevo;
  final VoidCallback? onGenerarNuevoEnEspera;

  Widget _contenido(QrTemporalApp? qrActual) {
    if (qrActual == null) {
      return _QrSinGenerar(mostrarAyudaBicicletero: mostrarAyudaBicicletero);
    }

    final estadoActual = estado;
    if (estadoActual == EstadoQr.escaneado) {
      return QrEscaneado(
        esIngreso: qrActual.tipo == 'INGRESO',
        onGenerarNuevo: onGenerarNuevoEnEspera,
      );
    }
    if (estadoActual != null) {
      return QrResultado(
        confirmado: estadoActual == EstadoQr.confirmado,
        esIngreso: qrActual.tipo == 'INGRESO',
        motivo: motivo,
        segundosParaHistorial: segundosParaHistorial,
        onVerHistorial: onVerHistorial,
        onIntentarDeNuevo: onIntentarDeNuevo,
        bicicleteroNombre: qrActual.bicicletero?.nombre,
      );
    }

    return _QrActivo(
      token: qrActual.token,
      segundosRestantes: segundosRestantes,
      duracionTotal: qrActual.duracionSegundos,
    );
  }

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
              child: _contenido(qrActual),
            ),
          ),
        ),
      ),
    );
  }
}

class _QrSinGenerar extends StatelessWidget {
  const _QrSinGenerar({required this.mostrarAyudaBicicletero});

  final bool mostrarAyudaBicicletero;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('qr-sin-generar'),
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
