import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/widgets/campo_solo_lectura.dart';

const _alturaCampoGestionManual = 56.0;

const _paddingCampoGestionManual =
    EdgeInsets.symmetric(horizontal: 14, vertical: 14);

InputDecoration decoracionCampoGestionManual({
  required String labelText,
  String? hintText,
  String? errorText,
  String? helperText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool alignLabelWithHint = false,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    helperText: helperText,
    helperMaxLines: 2,
    helperStyle: const TextStyle(color: ColoresUbb.textoSecundario),
    errorMaxLines: 3,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    alignLabelWithHint: alignLabelWithHint,
    contentPadding: _paddingCampoGestionManual,
    constraints: const BoxConstraints(minHeight: _alturaCampoGestionManual),
  );
}

class DetalleBicicletaRegistrada extends StatelessWidget {
  const DetalleBicicletaRegistrada({
    super.key,
    required this.bicicleta,
  });

  final BicicletaApp bicicleta;

  @override
  Widget build(BuildContext context) {
    final estado = bicicleta.activa ? 'Activa' : 'Inactiva';
    final bicicletero = bicicleta.dentroBicicletero
        ? bicicleta.bicicleteroActualNombre ?? 'Bicicletero no informado'
        : 'No registra ingreso activo';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampoSoloLectura(
          decoracion: decoracionCampoGestionManual(labelText: 'Bicicleta'),
          valor: bicicleta.descripcion,
        ),
        const SizedBox(height: 10),
        CampoSoloLectura(
          decoracion: decoracionCampoGestionManual(labelText: 'Estado'),
          valor: estado,
        ),
        const SizedBox(height: 10),
        CampoSoloLectura(
          decoracion: decoracionCampoGestionManual(
            labelText: 'Bicicletero actual',
          ),
          valor: bicicletero,
        ),
      ],
    );
  }
}

class EstadoBusquedaManual extends StatelessWidget {
  const EstadoBusquedaManual({
    super.key,
    required this.buscando,
    required this.error,
  });

  final bool buscando;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (buscando) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(
                child: Text('Buscando coincidencias en la base de datos...')),
          ],
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          error!,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColoresUbb.rojoInstitucional,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class CajaBusquedaManual extends StatelessWidget {
  const CajaBusquedaManual({
    super.key,
    required this.icono,
    required this.color,
    required this.children,
  });

  final IconData icono;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
