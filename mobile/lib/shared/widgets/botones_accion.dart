import 'package:flutter/material.dart';

import 'package:ubbike/core/tema/colores_ubb.dart';

const _separacion = 10.0;
const _paddingHorizontal = 14.0;
const _ladoIcono = 18.0;
const _espacioIcono = 8.0;

class AccionBoton {
  const AccionBoton({
    required this.texto,
    required this.color,
    required this.onPressed,
    this.icono,
    this.clave,
    this.cargando = false,
  });

  final String texto;
  final Color color;
  final VoidCallback? onPressed;
  final IconData? icono;
  final Key? clave;
  final bool cargando;
}

class BotonesAccion extends StatelessWidget {
  const BotonesAccion({
    super.key,
    required this.secundaria,
    required this.principal,
    this.principalALaIzquierda = false,
  });

  BotonesAccion.confirmacion({
    super.key,
    required String textoConfirmar,
    required VoidCallback? onConfirmar,
    required VoidCallback? onCancelar,
    bool destructiva = false,
    String textoCancelar = 'Cancelar',
    IconData? iconoConfirmar,
    IconData? iconoCancelar,
    Key? claveConfirmar,
    Key? claveCancelar,
    bool cargando = false,
  })  : secundaria = AccionBoton(
          texto: textoCancelar,
          color:
              destructiva ? ColoresUbb.azulApp : ColoresUbb.rojoInstitucional,
          onPressed: onCancelar,
          icono: iconoCancelar,
          clave: claveCancelar,
        ),
        principal = AccionBoton(
          texto: textoConfirmar,
          color:
              destructiva ? ColoresUbb.rojoInstitucional : ColoresUbb.azulApp,
          onPressed: onConfirmar,
          icono: iconoConfirmar,
          clave: claveConfirmar,
          cargando: cargando,
        ),
        principalALaIzquierda = false;

  final AccionBoton secundaria;
  final AccionBoton principal;
  final bool principalALaIzquierda;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final botonSecundario = _BotonAccion(accion: secundaria);
        final botonPrincipal = _BotonAccion(accion: principal);

        if (_cabenEnFila(context, constraints.maxWidth)) {
          final izquierda =
              principalALaIzquierda ? botonPrincipal : botonSecundario;
          final derecha =
              principalALaIzquierda ? botonSecundario : botonPrincipal;
          return Row(
            children: [
              Expanded(child: izquierda),
              const SizedBox(width: _separacion),
              Expanded(child: derecha),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            botonPrincipal,
            const SizedBox(height: _separacion),
            botonSecundario,
          ],
        );
      },
    );
  }

  bool _cabenEnFila(BuildContext context, double anchoDisponible) {
    if (!anchoDisponible.isFinite) {
      return true;
    }
    final anchoPorBoton = (anchoDisponible - _separacion) / 2;
    return _anchoNecesario(context, secundaria) <= anchoPorBoton &&
        _anchoNecesario(context, principal) <= anchoPorBoton;
  }

  double _anchoNecesario(BuildContext context, AccionBoton accion) {
    final tema = Theme.of(context);
    final estiloTema = tema.elevatedButtonTheme.style?.textStyle
        ?.resolve(const <WidgetState>{});
    final pintor = TextPainter(
      text: TextSpan(
        text: accion.texto,
        style: tema.textTheme.labelLarge?.merge(estiloTema),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final anchoTexto = pintor.width;
    pintor.dispose();

    final conIcono = accion.icono != null || accion.cargando;
    return anchoTexto +
        (conIcono ? _ladoIcono + _espacioIcono : 0) +
        _paddingHorizontal * 2;
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({required this.accion});

  final AccionBoton accion;

  @override
  Widget build(BuildContext context) {
    final estilo = ElevatedButton.styleFrom(
      backgroundColor: accion.color,
      foregroundColor: Colors.white,
      disabledBackgroundColor: ColoresUbb.grisInstitucional,
      disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
      padding: const EdgeInsets.symmetric(horizontal: _paddingHorizontal),
    );
    final texto = Text(
      accion.texto,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
    final icono = accion.cargando
        ? const SizedBox(
            width: _ladoIcono,
            height: _ladoIcono,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : accion.icono == null
            ? null
            : Icon(accion.icono);

    if (icono == null) {
      return ElevatedButton(
        key: accion.clave,
        style: estilo,
        onPressed: accion.onPressed,
        child: texto,
      );
    }

    return ElevatedButton.icon(
      key: accion.clave,
      style: estilo,
      onPressed: accion.onPressed,
      icon: icono,
      label: texto,
    );
  }
}
