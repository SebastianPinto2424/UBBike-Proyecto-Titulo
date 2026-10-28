import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/incidencia_modelos.dart';
import 'package:ubbike/shared/utilidades/utiles_comun.dart';

String etiquetaFotosIncidencia(int cantidad) {
  return cantidad == 1
      ? '1 imagen de evidencia'
      : '$cantidad imágenes de evidencia';
}

class GaleriaFotosIncidencia extends StatelessWidget {
  const GaleriaFotosIncidencia({super.key, required this.fotos});

  final List<FotoIncidenciaApp> fotos;

  @override
  Widget build(BuildContext context) {
    if (fotos.isEmpty) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ColoresUbb.superficieAzulSuave,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresUbb.azulApp.withValues(alpha: 0.25)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: ColoresUbb.azulApp,
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etiquetaFotosIncidencia(fotos.length),
                      style: textTheme.labelMedium?.copyWith(
                        color: ColoresUbb.azulApp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final foto in fotos)
                          _MiniaturaEvidencia(foto: foto),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniaturaEvidencia extends StatelessWidget {
  const _MiniaturaEvidencia({required this.foto});

  final FotoIncidenciaApp foto;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => mostrarFotoBicicletaAmpliada(context, foto.url),
        child: Stack(
          children: [
            Image.network(
              resolverUrlFotoBicicleta(foto.url),
              width: 84,
              height: 84,
              fit: BoxFit.cover,
              cacheWidth: 168,
              cacheHeight: 168,
              errorBuilder: (_, __, ___) => Container(
                width: 84,
                height: 84,
                color: ColoresUbb.superficieAzul,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: ColoresUbb.textoSecundario,
                ),
              ),
            ),
            const Positioned(
              right: 4,
              bottom: 4,
              child: Icon(
                Icons.open_in_full,
                size: 14,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
