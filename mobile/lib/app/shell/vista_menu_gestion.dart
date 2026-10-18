import 'package:flutter/material.dart';

import 'package:ubbike/features/admin/presentation/vista_gestion_bicicleteros.dart';
import 'package:ubbike/features/admin/presentation/vista_gestion_usuarios.dart';
import 'package:ubbike/features/historial/presentation/vista_movimientos_central.dart';
import 'package:ubbike/app/shell/vista_soporte.dart';
import 'package:ubbike/shared/widgets/contenedor_responsivo.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';

void abrirSeccionGestion(
  BuildContext context, {
  required String titulo,
  required Widget pantalla,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: ContenedorResponsivo(
          anchoMaximo: 940,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: pantalla,
        ),
      ),
    ),
  );
}

class VistaMenuGestionAdmin extends StatelessWidget {
  const VistaMenuGestionAdmin({super.key, this.initialSoporteIndex = 0});

  final int initialSoporteIndex;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        TarjetaAccion(
          icono: Icons.manage_accounts_outlined,
          titulo: 'Usuarios y permisos',
          detalle: 'Roles, accesos y verificación de cuentas.',
          onTap: () => abrirSeccionGestion(
            context,
            titulo: 'Usuarios y permisos',
            pantalla: const VistaGestionUsuarios(),
          ),
        ),
        const SizedBox(height: 12),
        TarjetaAccion(
          icono: Icons.location_on_outlined,
          titulo: 'Bicicleteros',
          detalle: 'Puntos de ingreso y retiro habilitados en el campus.',
          onTap: () => abrirSeccionGestion(
            context,
            titulo: 'Bicicleteros',
            pantalla: const VistaGestionBicicleteros(),
          ),
        ),
        const SizedBox(height: 12),
        TarjetaAccion(
          icono: Icons.manage_search_outlined,
          titulo: 'Movimientos',
          detalle: 'Historial de ingresos y retiros del campus.',
          onTap: () => abrirSeccionGestion(
            context,
            titulo: 'Movimientos',
            pantalla: const VistaMovimientosCentral(),
          ),
        ),
        const SizedBox(height: 12),
        TarjetaAccion(
          icono: Icons.support_agent_outlined,
          titulo: 'Atención',
          detalle: 'Guardias, solicitudes de apoyo e incidencias.',
          onTap: () => abrirSeccionGestion(
            context,
            titulo: 'Atención',
            pantalla:
                VistaSoporteAdministrador(initialIndex: initialSoporteIndex),
          ),
        ),
      ],
    );
  }
}
