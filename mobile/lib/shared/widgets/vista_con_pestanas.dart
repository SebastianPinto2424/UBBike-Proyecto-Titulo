import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';

class VistaConPestanas extends StatelessWidget {
  const VistaConPestanas({
    super.key,
    required this.pestanas,
    required this.vistas,
    this.initialIndex = 0,
  });

  final List<Tab> pestanas;
  final List<Widget> vistas;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: pestanas.length,
      initialIndex: initialIndex,
      child: Column(
        children: [
          Material(
            color: ColoresUbb.superficieAzulSuave,
            borderRadius: BorderRadius.circular(14),
            child: TabBar(
              tabs: pestanas,
              padding: const EdgeInsets.all(4),
              labelColor: Colors.white,
              unselectedLabelColor: ColoresUbb.textoSecundario,
              indicator: BoxDecoration(
                color: ColoresUbb.azulApp,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              splashBorderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(children: vistas),
          ),
        ],
      ),
    );
  }
}

Tab pestanaCompacta(IconData icono, String texto) {
  return Tab(
    height: 44,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icono, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
