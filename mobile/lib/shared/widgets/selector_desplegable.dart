import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';

class CampoDesplegable extends StatelessWidget {
  const CampoDesplegable({
    super.key,
    required this.etiqueta,
    required this.texto,
    required this.abierto,
    required this.onTap,
    this.icono = Icons.location_on_outlined,
    this.vacio = false,
    this.maxLineas = 1,
  });

  final String etiqueta;
  final String texto;
  final bool abierto;
  final VoidCallback? onTap;
  final IconData icono;
  final bool vacio;
  final int maxLineas;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ColoresUbb.bordeFuerte),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(icono, color: ColoresUbb.azulApp),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          texto,
                          maxLines: maxLineas,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: vacio
                                        ? ColoresUbb.textoSecundario
                                        : ColoresUbb.textoPrincipal,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ),
                      Icon(
                        abierto
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: ColoresUbb.textoSecundario,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Text(
              etiqueta,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ColoresUbb.azulApp,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class PanelOpcionesDesplegable extends StatelessWidget {
  const PanelOpcionesDesplegable({
    super.key,
    required this.abierto,
    required this.opciones,
  });

  final bool abierto;
  final List<Widget> opciones;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 180),
      crossFadeState:
          abierto ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: const SizedBox.shrink(),
      secondChild: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ColoresUbb.fondo,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColoresUbb.borde),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: opciones,
            ),
          ),
        ),
      ),
    );
  }
}

class OpcionDesplegable extends StatelessWidget {
  const OpcionDesplegable({
    super.key,
    required this.titulo,
    this.detalle,
    this.seleccionada = false,
    this.bloqueada = false,
    this.cargando = false,
    this.onTap,
  });

  final String titulo;
  final String? detalle;
  final bool seleccionada;
  final bool bloqueada;
  final bool cargando;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: seleccionada
                  ? ColoresUbb.azulApp.withValues(alpha: 0.08)
                  : bloqueada
                      ? ColoresUbb.superficieAzul
                      : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: seleccionada ? ColoresUbb.azulApp : ColoresUbb.borde,
                width: seleccionada ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      if (detalle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          detalle!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: ColoresUbb.textoSecundario,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (cargando)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    seleccionada
                        ? Icons.check_circle
                        : bloqueada
                            ? Icons.lock_outline
                            : Icons.radio_button_unchecked,
                    color: seleccionada
                        ? ColoresUbb.azulApp
                        : ColoresUbb.textoSecundario,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
