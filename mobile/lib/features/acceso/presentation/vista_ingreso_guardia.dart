import 'package:flutter/material.dart';

import 'package:ubbike/shared/widgets/vista_con_pestanas.dart';
import 'package:ubbike/features/acceso/presentation/vista_escaner_qr_guardia.dart';
import 'package:ubbike/features/acceso/presentation/vista_gestion_manual_guardia.dart';

enum ModoIngresoGuardia { qr, manual }

extension _PestanasModoIngresoGuardia on ModoIngresoGuardia {
  int get indice {
    return switch (this) {
      ModoIngresoGuardia.qr => 0,
      ModoIngresoGuardia.manual => 1,
    };
  }
}

class VistaIngresoGuardia extends StatelessWidget {
  const VistaIngresoGuardia({
    super.key,
    required this.modoInicial,
    this.onIrAHistorial,
  });

  final ModoIngresoGuardia modoInicial;

  final VoidCallback? onIrAHistorial;

  @override
  Widget build(BuildContext context) {
    return VistaConPestanas(
      key: ValueKey(modoInicial),
      initialIndex: modoInicial.indice,
      pestanas: [
        pestanaCompacta(Icons.qr_code_scanner, 'QR'),
        pestanaCompacta(Icons.edit_note_outlined, 'Manual'),
      ],
      vistas: [
        VistaEscanerQrGuardia(onMovimientoRegistrado: onIrAHistorial),
        VistaGestionManualGuardia(onMovimientoRegistrado: onIrAHistorial),
      ],
    );
  }
}
