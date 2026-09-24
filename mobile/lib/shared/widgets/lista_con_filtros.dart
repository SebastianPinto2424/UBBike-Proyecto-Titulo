import 'package:flutter/material.dart';

class ListaConFiltros extends StatelessWidget {
  const ListaConFiltros({
    super.key,
    required this.cabecera,
    required this.contenido,
    this.onRefrescar,
    this.separacion = 16,
    this.espacioFinal = 24,
  });

  final List<Widget> cabecera;
  final Widget contenido;
  final Future<void> Function()? onRefrescar;
  final double separacion;
  final double espacioFinal;

  @override
  Widget build(BuildContext context) {
    final vista = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...cabecera,
              SizedBox(height: separacion),
            ],
          ),
        ),
        contenido,
        SliverToBoxAdapter(child: SizedBox(height: espacioFinal)),
      ],
    );

    final refrescar = onRefrescar;
    if (refrescar == null) {
      return vista;
    }

    return RefreshIndicator(onRefresh: refrescar, child: vista);
  }
}

class SliverEspacioRestante extends StatelessWidget {
  const SliverEspacioRestante({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(hasScrollBody: false, child: child);
  }
}

class SliverCargando extends StatelessWidget {
  const SliverCargando({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverEspacioRestante(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
