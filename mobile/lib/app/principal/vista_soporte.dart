import 'package:flutter/material.dart';

import 'package:ubbike/shared/widgets/vista_con_pestanas.dart';
import 'package:ubbike/features/acceso/presentation/vista_guardias_en_turno.dart';
import 'package:ubbike/features/acceso/presentation/vista_solicitar_guardia.dart';
import 'package:ubbike/features/acceso/presentation/vista_alertas_guardia.dart';
import 'package:ubbike/features/historial/presentation/vista_operaciones_guardias_central.dart';
import 'package:ubbike/features/acceso/presentation/vista_solicitudes_central.dart';
import 'package:ubbike/features/incidencias/presentation/vista_incidencias.dart';

class VistaSoporteUsuario extends StatelessWidget {
  const VistaSoporteUsuario({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return VistaConPestanas(
      initialIndex: initialIndex,
      pestanas: [
        pestanaCompacta(Icons.headset_mic_outlined, 'Atención'),
        pestanaCompacta(Icons.flag_outlined, 'Incidencias'),
      ],
      vistas: const [
        VistaSolicitarGuardia(),
        VistaIncidencias(
          mostrarReportante: false,
          puedeGestionar: false,
          permitirBicicletaPropia: true,
          soloPropias: true,
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
    return VistaConPestanas(
      initialIndex: initialIndex,
      pestanas: [
        pestanaCompacta(Icons.notifications_active_outlined, 'Alertas'),
        pestanaCompacta(Icons.report_problem_outlined, 'Incidencias'),
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
    return VistaConPestanas(
      initialIndex: initialIndex,
      pestanas: [
        pestanaCompacta(Icons.campaign_outlined, 'Solicitudes'),
        pestanaCompacta(Icons.report_problem_outlined, 'Incidencias'),
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

class VistaGuardias extends StatelessWidget {
  const VistaGuardias({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return VistaConPestanas(
      initialIndex: initialIndex,
      pestanas: [
        pestanaCompacta(Icons.shield_outlined, 'En turno'),
        pestanaCompacta(Icons.query_stats_outlined, 'Operaciones'),
      ],
      vistas: const [
        VistaGuardiasEnTurno(),
        VistaOperacionesGuardiasCentral(),
      ],
    );
  }
}

class VistaSoporteAdministrador extends StatelessWidget {
  const VistaSoporteAdministrador({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return VistaConPestanas(
      initialIndex: initialIndex,
      pestanas: [
        pestanaCompacta(Icons.campaign_outlined, 'Solicitudes'),
        pestanaCompacta(Icons.report_problem_outlined, 'Incidencias'),
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
