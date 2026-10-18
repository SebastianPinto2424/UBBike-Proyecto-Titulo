import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';

class QrTemporal extends StatelessWidget {
  const QrTemporal({
    super.key,
    required this.token,
    required this.segundosRestantes,
  });

  final String token;
  final int segundosRestantes;

  @override
  Widget build(BuildContext context) {
    final expirado = segundosRestantes <= 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoDisponible =
            constraints.maxWidth.isFinite ? constraints.maxWidth - 28 : 240.0;
        final dimensionQr = anchoDisponible.clamp(160.0, 240.0).toDouble();

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ColoresUbb.bordeFuerte),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: expirado ? 0.22 : 1,
                  child: QrImageView(
                    data: token,
                    version: QrVersions.auto,
                    size: dimensionQr,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: ColoresUbb.textoPrincipal,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: ColoresUbb.textoPrincipal,
                    ),
                  ),
                ),
                if (expirado)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: ColoresUbb.rojoInstitucional,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'Expirado',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class QrEscaneado extends StatelessWidget {
  const QrEscaneado({
    super.key,
    required this.esIngreso,
    this.onGenerarNuevo,
  });

  final bool esIngreso;
  final VoidCallback? onGenerarNuevo;

  @override
  Widget build(BuildContext context) {
    final operacion = esIngreso ? 'ingreso' : 'retiro';

    return Column(
      key: const ValueKey('qr-escaneado'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const _IconoEstadoQr(
          icono: Icons.hourglass_top,
          color: ColoresUbb.azulApp,
        ),
        const SizedBox(height: 16),
        Text(
          'Revisando tu $operacion',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: ColoresUbb.azulNoche,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'El guardia está verificando tus datos y los de tu bicicleta. '
          'Mantente en esta pantalla para ver el resultado.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ColoresUbb.textoSecundario,
              ),
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: const LinearProgressIndicator(
            minHeight: 6,
            backgroundColor: ColoresUbb.bordeFuerte,
            valueColor: AlwaysStoppedAnimation(ColoresUbb.azulApp),
          ),
        ),
        if (onGenerarNuevo != null) ...[
          const SizedBox(height: 16),
          Text(
            '¿El guardia no responde?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColoresUbb.textoSecundario,
                ),
          ),
          TextButton.icon(
            onPressed: onGenerarNuevo,
            icon: const Icon(Icons.refresh),
            label: const Text('Generar nuevo QR'),
          ),
        ],
      ],
    );
  }
}

class QrResultado extends StatelessWidget {
  const QrResultado({
    super.key,
    required this.confirmado,
    required this.esIngreso,
    required this.motivo,
    required this.segundosParaHistorial,
    required this.onVerHistorial,
    required this.onIntentarDeNuevo,
    this.bicicleteroNombre,
  });

  final bool confirmado;
  final bool esIngreso;
  final String? motivo;
  final int segundosParaHistorial;
  final VoidCallback onVerHistorial;
  final VoidCallback onIntentarDeNuevo;
  final String? bicicleteroNombre;

  String get _titulo {
    final operacion = esIngreso ? 'Ingreso' : 'Retiro';
    return confirmado ? '$operacion confirmado' : '$operacion denegado';
  }

  String get _detalle {
    if (confirmado) {
      final bicicletero = bicicleteroNombre;
      if (!esIngreso) {
        return 'Ya puedes llevarte tu bicicleta.';
      }
      return bicicletero == null
          ? 'Tu bicicleta quedó registrada en el bicicletero.'
          : 'Tu bicicleta quedó guardada en $bicicletero.';
    }
    final motivoActual = motivo;
    return motivoActual == null
        ? 'El guardia no aprobó el movimiento.'
        : 'Motivo: $motivoActual';
  }

  @override
  Widget build(BuildContext context) {
    final color = confirmado ? ColoresUbb.exito : ColoresUbb.rojoInstitucional;

    return Column(
      key: ValueKey('qr-resultado-$confirmado'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconoEstadoQr(
          icono: confirmado ? Icons.check_circle_outline : Icons.block,
          color: color,
        ),
        const SizedBox(height: 16),
        Text(
          _titulo,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          _detalle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ColoresUbb.textoSecundario,
              ),
        ),
        const SizedBox(height: 20),
        if (confirmado) ...[
          Text(
            segundosParaHistorial > 0
                ? 'Te llevamos a tu historial en $segundosParaHistorial s'
                : 'Abriendo tu historial…',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColoresUbb.textoSecundario,
                ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onVerHistorial,
            icon: const Icon(Icons.history),
            label: const Text('Ver historial ahora'),
          ),
        ] else ...[
          ElevatedButton.icon(
            onPressed: onIntentarDeNuevo,
            icon: const Icon(Icons.refresh),
            label: const Text('Generar nuevo QR'),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onVerHistorial,
            icon: const Icon(Icons.history),
            label: const Text('Ver historial'),
          ),
        ],
      ],
    );
  }
}

class _IconoEstadoQr extends StatelessWidget {
  const _IconoEstadoQr({required this.icono, required this.color});

  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icono, color: color, size: 56),
    );
  }
}
