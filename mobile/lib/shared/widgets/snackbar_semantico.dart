import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';

extension SnackBarSemantico on BuildContext {
  void mostrarAvisoUnico(SnackBar aviso) {
    ScaffoldMessenger.of(this)
      ..clearSnackBars()
      ..showSnackBar(aviso);
  }

  void mostrarExito(String mensaje) {
    mostrarAvisoUnico(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: ColoresUbb.turquesa),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: ColoresUbb.azulNoche,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void mostrarError(String mensaje) {
    mostrarAvisoUnico(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: ColoresUbb.rojoInstitucional,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void mostrarInfo(String mensaje) {
    mostrarAvisoUnico(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: ColoresUbb.azulNoche,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
