import 'package:flutter/material.dart';

import 'package:ubbike/shared/widgets/vista_con_tabs.dart';
import 'package:ubbike/features/qr/presentation/vista_qr_usuario.dart';
import 'package:ubbike/features/acceso/presentation/vista_solicitar_guardia.dart';
import 'package:ubbike/features/acceso/presentation/vista_escaner_qr_guardia.dart';
import 'package:ubbike/features/acceso/presentation/vista_gestion_manual_guardia.dart';
import 'package:ubbike/features/acceso/presentation/vista_alertas_guardia.dart';
import 'package:ubbike/features/acceso/presentation/vista_operaciones_guardias_central.dart';
import 'package:ubbike/features/acceso/presentation/vista_solicitudes_central.dart';
import 'package:ubbike/features/incidencias/presentation/vista_incidencias.dart';

class VistaSoporteUsuario extends StatelessWidget {
  const VistaSoporteUsuario({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return VistaConTabs(
      initialIndex: initialIndex,
      tabs: [
        tabCompacto(Icons.headset_mic_outlined, 'Atención'),
        tabCompacto(Icons.flag_outlined, 'Incidencias'),
      ],
      vistas: const [
        VistaSolicitarGuardia(),
        VistaIncidencias(
          mostrarReportante: false,
          puedeGestionar: false,
          permitirBicicletaPropia: true,
        ),
      ],
    );
  }
}

class VistaSoporteGuardia extends StatelessWidget {
  const VistaSoporteGuardia({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return VistaConTabs(
      initialIndex: initialIndex,
      tabs: [
        tabCompacto(Icons.notifications_active_outlined, 'Alertas'),
        tabCompacto(Icons.report_problem_outlined, 'Incidencias'),
      ],
      vistas: const [
        VistaAlertasGuardia(),
        VistaIncidencias(
          mostrarReportante: true,
          puedeGestionar: false,
          gestionGuardia: true,
        ),
      ],
    );
  }
}

class VistaSoporteCentral extends StatelessWidget {
  const VistaSoporteCentral({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return VistaConTabs(
      initialIndex: initialIndex,
      tabs: [
        tabCompacto(Icons.campaign_outlined, 'Solicitudes'),
        tabCompacto(Icons.report_problem_outlined, 'Incidencias'),
      ],
      vistas: const [
        VistaSolicitudesCentral(),
        VistaIncidencias(
          mostrarReportante: true,
          puedeGestionar: true,
          gestionCentral: true,
        ),
      ],
    );
  }
}

class VistaSoporteAdministrador extends StatelessWidget {
  const VistaSoporteAdministrador({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return VistaConTabs(
      initialIndex: initialIndex,
      tabs: [
        tabCompacto(Icons.security_outlined, 'Guardias'),
        tabCompacto(Icons.campaign_outlined, 'Solicitudes'),
        tabCompacto(Icons.report_problem_outlined, 'Incidencias'),
      ],
      vistas: const [
        VistaOperacionesGuardiasCentral(),
        VistaSolicitudesCentral(),
        VistaIncidencias(
          mostrarReportante: true,
          puedeGestionar: true,
          gestionCentral: true,
        ),
      ],
    );
  }
}

class VistaQrAdmin extends StatelessWidget {
  const VistaQrAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return VistaConTabs(
      tabs: [
        tabCompacto(Icons.qr_code_2, 'Generar'),
        tabCompacto(Icons.qr_code_scanner, 'Validar'),
        tabCompacto(Icons.edit_note_outlined, 'Manual'),
      ],
      vistas: const [
        VistaQrUsuario(),
        VistaEscanerQrGuardia(),
        VistaGestionManualGuardia(),
      ],
    );
  }
}
