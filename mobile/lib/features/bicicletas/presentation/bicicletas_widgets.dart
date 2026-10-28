import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/shared/utilidades/utiles_comun.dart';

class TarjetaBicicletaUsuario extends StatefulWidget {
  const TarjetaBicicletaUsuario({
    super.key,
    required this.bicicleta,
    required this.onEditar,
    required this.onEliminar,
    required this.onCambiarActiva,
  });

  final BicicletaApp bicicleta;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final ValueChanged<bool> onCambiarActiva;

  @override
  State<TarjetaBicicletaUsuario> createState() =>
      TarjetaBicicletaUsuarioState();
}

class TarjetaBicicletaUsuarioState extends State<TarjetaBicicletaUsuario> {
  bool gestionAbierta = false;

  void _mostrarFotoAmpliada(BuildContext context, String fotoReferencia) {
    mostrarFotoBicicletaAmpliada(context, fotoReferencia);
  }

  @override
  Widget build(BuildContext context) {
    final bicicleta = widget.bicicleta;

    return Card(
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: ColoresUbb.borde),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bicicleta.descripcion,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: ColoresUbb.azulNoche,
                                ),
                      ),
                      const SizedBox(height: 6),
                      _EstadoActualBicicleta(bicicleta: bicicleta),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ChipEstado(
                  texto: bicicleta.activa ? 'Activa' : 'Inactiva',
                  color: bicicleta.activa
                      ? ColoresUbb.exito
                      : ColoresUbb.textoSecundario,
                ),
              ],
            ),
            if (bicicleta.fotoUrl != null && bicicleta.fotoUrl!.isNotEmpty) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => _mostrarFotoAmpliada(context, bicicleta.fotoUrl!),
                child: Stack(
                  children: [
                    _ImagenBicicleta(fotoReferencia: bicicleta.fotoUrl!),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.zoom_in_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Detalles',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ColoresUbb.azulNoche,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            _FichaDetalleBicicleta(bicicleta: bicicleta),
            const SizedBox(height: 14),
            _BotonGestionBicicleta(
              expandido: gestionAbierta,
              onTap: () => setState(() => gestionAbierta = !gestionAbierta),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: gestionAbierta
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: _PanelGestionBicicleta(
                bicicleta: bicicleta,
                onCambiarActiva: widget.onCambiarActiva,
                onEditar: widget.onEditar,
                onEliminar: widget.onEliminar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoActualBicicleta extends StatelessWidget {
  const _EstadoActualBicicleta({required this.bicicleta});

  final BicicletaApp bicicleta;

  @override
  Widget build(BuildContext context) {
    final texto = bicicleta.dentroBicicletero
        ? 'Dentro - ${bicicleta.bicicleteroActualNombre ?? 'Bicicletero no informado'}'
        : 'Fuera del bicicletero';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          bicicleta.dentroBicicletero
              ? Icons.location_on_outlined
              : Icons.logout_outlined,
          size: 18,
          color: ColoresUbb.azulApp,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColoresUbb.textoSecundario,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _FichaDetalleBicicleta extends StatelessWidget {
  const _FichaDetalleBicicleta({required this.bicicleta});

  final BicicletaApp bicicleta;

  String _valorInformado(String? valor) {
    final limpio = valor?.trim();
    return limpio == null || limpio.isEmpty ? 'No informado' : limpio;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FilaDetalleBicicleta(
          etiqueta: 'Marca',
          valor: _valorInformado(bicicleta.marca),
        ),
        const Divider(height: 1, color: ColoresUbb.borde),
        _FilaDetalleBicicleta(
          etiqueta: 'Modelo',
          valor: _valorInformado(bicicleta.modelo),
        ),
        const Divider(height: 1, color: ColoresUbb.borde),
        _FilaDetalleBicicleta(
          etiqueta: 'Color',
          valor: _valorInformado(bicicleta.color),
        ),
        const Divider(height: 1, color: ColoresUbb.borde),
        _FilaDetalleBicicleta(
          etiqueta: 'Aro',
          valor: _valorInformado(bicicleta.aro),
        ),
        const Divider(height: 1, color: ColoresUbb.borde),
        _FilaDetalleBicicleta(
          etiqueta: 'Nro. serie',
          valor: _valorInformado(bicicleta.numeroSerie),
        ),
      ],
    );
  }
}

class _FilaDetalleBicicleta extends StatelessWidget {
  const _FilaDetalleBicicleta({
    required this.etiqueta,
    required this.valor,
  });

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              etiqueta,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColoresUbb.textoSecundario,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              softWrap: true,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ColoresUbb.azulNoche,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonGestionBicicleta extends StatelessWidget {
  const _BotonGestionBicicleta({
    required this.expandido,
    required this.onTap,
  });

  final bool expandido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ColoresUbb.bordeFuerte),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.settings_outlined, color: ColoresUbb.azulApp),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Gestionar bicicleta',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ColoresUbb.textoPrincipal,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Icon(
                  expandido
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: ColoresUbb.textoSecundario,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelGestionBicicleta extends StatelessWidget {
  const _PanelGestionBicicleta({
    required this.bicicleta,
    required this.onCambiarActiva,
    required this.onEditar,
    required this.onEliminar,
  });

  final BicicletaApp bicicleta;
  final ValueChanged<bool> onCambiarActiva;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ColoresUbb.fondo,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ColoresUbb.borde),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bicicleta.activa ? 'Activa' : 'Inactiva',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        Text(
                          'Solo una bicicleta puede quedar activa.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: ColoresUbb.textoSecundario,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: bicicleta.activa,
                    onChanged: (valor) => onCambiarActiva(valor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onEditar,
                      style: FilledButton.styleFrom(
                        backgroundColor: ColoresUbb.azulApp,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Editar'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onEliminar,
                      style: FilledButton.styleFrom(
                        backgroundColor: ColoresUbb.rojoInstitucional,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Eliminar'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagenBicicleta extends StatelessWidget {
  const _ImagenBicicleta({required this.fotoReferencia});

  final String fotoReferencia;

  @override
  Widget build(BuildContext context) {
    final bytesFoto = decodificarFotoDataUrl(fotoReferencia);
    if (bytesFoto == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          resolverUrlFotoBicicleta(fotoReferencia),
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 150,
            width: double.infinity,
            color: ColoresUbb.superficieAzulSuave,
            child: const Icon(
              Icons.pedal_bike_outlined,
              color: ColoresUbb.azulApp,
              size: 46,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        bytesFoto,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}
