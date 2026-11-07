import 'package:flutter/material.dart';

import 'package:ubbike/app/principal/vista_menu_gestion.dart';
import 'package:ubbike/app/principal/vista_soporte.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/features/bicicletas/presentation/vista_bicicletas_usuario.dart';
import 'package:ubbike/features/historial/presentation/vista_movimientos_usuario.dart';
import 'package:ubbike/features/perfil/presentation/pantalla_principal_perfil.dart';
import 'package:ubbike/features/qr/presentation/vista_qr_usuario.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/vista_con_pestanas.dart';

const pestanaMovimientosPersonales = 2;

void abrirBicicletasPersonales(BuildContext context, {int pestana = 0}) {
  abrirSeccionGestion(
    context,
    titulo: 'Mis bicicletas',
    pantalla: VistaBicicletasPersonales(pestanaInicial: pestana),
  );
}

void abrirAtencionPersonal(BuildContext context, {int pestana = 0}) {
  abrirSeccionGestion(
    context,
    titulo: 'Atención e incidencias',
    pantalla: VistaSoporteUsuario(initialIndex: pestana),
  );
}

class VistaSeccionPersonal extends StatelessWidget {
  const VistaSeccionPersonal({super.key, required this.rol});

  final RolUsuario rol;

  @override
  Widget build(BuildContext context) {
    return VistaConPestanas(
      pestanas: [
        pestanaCompacta(Icons.pedal_bike_outlined, 'Mi bicicleta'),
        pestanaCompacta(Icons.person_outline, 'Perfil'),
      ],
      vistas: [
        _MenuPersonal(
          onAbrirBicicletas: () => abrirBicicletasPersonales(context),
          onAbrirAtencion: () => abrirAtencionPersonal(context),
        ),
        VistaPerfil(rol: rol),
      ],
    );
  }
}

class _MenuPersonal extends StatelessWidget {
  const _MenuPersonal({
    required this.onAbrirBicicletas,
    required this.onAbrirAtencion,
  });

  final VoidCallback onAbrirBicicletas;
  final VoidCallback onAbrirAtencion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        TarjetaAccion(
          icono: Icons.pedal_bike_outlined,
          titulo: 'Mis bicicletas',
          detalle:
              'Registra tu bicicleta, genera tu QR y revisa tus movimientos.',
          onTap: onAbrirBicicletas,
        ),
        const SizedBox(height: 12),
        TarjetaAccion(
          icono: Icons.support_agent_outlined,
          titulo: 'Atención e incidencias',
          detalle: 'Pide apoyo a un guardia o reporta un problema.',
          onTap: onAbrirAtencion,
        ),
      ],
    );
  }
}

class VistaBicicletasPersonales extends StatefulWidget {
  const VistaBicicletasPersonales({super.key, this.pestanaInicial = 0});

  final int pestanaInicial;

  @override
  State<VistaBicicletasPersonales> createState() =>
      _VistaBicicletasPersonalesState();
}

class _VistaBicicletasPersonalesState extends State<VistaBicicletasPersonales> {
  late int _pestana = widget.pestanaInicial;
  int _navegaciones = 0;

  void _verMovimientos() {
    setState(() {
      _pestana = pestanaMovimientosPersonales;
      _navegaciones++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return VistaBicicletas(
      key: ValueKey('bicicletas-personales-$_pestana-$_navegaciones'),
      initialIndex: _pestana,
      vistaQr: VistaQrUsuario(onVerHistorial: _verMovimientos),
      vistaMovimientos: const VistaMovimientosUsuario(),
    );
  }
}
