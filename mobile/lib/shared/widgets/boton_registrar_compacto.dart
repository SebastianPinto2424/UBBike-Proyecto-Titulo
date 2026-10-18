import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';

class BotonRegistrarCompacto extends StatelessWidget {
  const BotonRegistrarCompacto({
    super.key,
    required this.texto,
    required this.onPressed,
  });

  final String texto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        backgroundColor: ColoresUbb.azulApp,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
