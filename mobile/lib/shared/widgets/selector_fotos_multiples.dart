import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/utilidades/utiles_comun.dart';

class SelectorFotosMultiples extends StatelessWidget {
  const SelectorFotosMultiples({
    super.key,
    required this.fotos,
    required this.maximo,
    required this.onCamara,
    required this.onGaleria,
    required this.onQuitar,
    this.titulo = 'Fotos de respaldo',
    this.ayuda,
    this.habilitado = true,
  });

  final List<String> fotos;
  final int maximo;
  final VoidCallback onCamara;
  final VoidCallback onGaleria;
  final ValueChanged<int> onQuitar;
  final String titulo;
  final String? ayuda;
  final bool habilitado;

  bool get _puedeAgregar => habilitado && fotos.length < maximo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                titulo,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: ColoresUbb.azulApp,
                    ),
              ),
            ),
            Text(
              '${fotos.length} de $maximo',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColoresUbb.textoSecundario,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        if (ayuda != null) ...[
          const SizedBox(height: 4),
          Text(
            ayuda!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColoresUbb.textoSecundario,
                ),
          ),
        ],
        const SizedBox(height: 10),
        if (fotos.isEmpty)
          _SinFotos()
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var indice = 0; indice < fotos.length; indice++)
                _MiniaturaFoto(
                  referencia: fotos[indice],
                  onAmpliar: () =>
                      mostrarFotoBicicletaAmpliada(context, fotos[indice]),
                  onQuitar: habilitado ? () => onQuitar(indice) : null,
                ),
            ],
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _puedeAgregar ? onCamara : null,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Tomar foto'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _puedeAgregar ? onGaleria : null,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Subir foto'),
              ),
            ),
          ],
        ),
        if (!_puedeAgregar && habilitado) ...[
          const SizedBox(height: 6),
          Text(
            'Alcanzaste el máximo de $maximo fotos.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColoresUbb.textoSecundario,
                ),
          ),
        ],
      ],
    );
  }
}

class _SinFotos extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: ColoresUbb.superficieAzulSuave,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresUbb.borde),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_a_photo_outlined,
              size: 30, color: ColoresUbb.textoSecundario),
          const SizedBox(height: 6),
          Text(
            'Sin fotos adjuntas',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColoresUbb.textoSecundario,
                ),
          ),
        ],
      ),
    );
  }
}

const int _ladoMiniaturaCache = 192;

class _MiniaturaFoto extends StatelessWidget {
  const _MiniaturaFoto({
    required this.referencia,
    required this.onAmpliar,
    required this.onQuitar,
  });

  final String referencia;
  final VoidCallback onAmpliar;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    final bytes = decodificarFotoDataUrl(referencia);

    final Widget imagen = bytes != null
        ? Image.memory(
            bytes,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            cacheWidth: _ladoMiniaturaCache,
            cacheHeight: _ladoMiniaturaCache,
          )
        : Image.network(
            resolverUrlFotoBicicleta(referencia),
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            cacheWidth: _ladoMiniaturaCache,
            cacheHeight: _ladoMiniaturaCache,
            errorBuilder: (_, __, ___) => Container(
              width: 96,
              height: 96,
              color: ColoresUbb.superficieAzul,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined,
                  color: ColoresUbb.textoSecundario),
            ),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onAmpliar, child: imagen),
        ),
        if (onQuitar != null)
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: ColoresUbb.rojoInstitucional,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onQuitar,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, color: Colors.white, size: 15),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
