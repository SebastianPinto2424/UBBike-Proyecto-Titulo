import 'package:flutter/material.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/utils/utiles_comun.dart';

class SelectorFoto extends StatelessWidget {
  const SelectorFoto({
    super.key,
    required this.fotoDataUrl,
    required this.onCamara,
    required this.onGaleria,
    required this.onQuitar,
    this.mostrarAcciones = true,
    this.errorText,
    this.titulo = 'Imagen',
  });

  final String? fotoDataUrl;
  final VoidCallback onCamara;
  final VoidCallback onGaleria;
  final VoidCallback? onQuitar;
  final bool mostrarAcciones;
  final String? errorText;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final foto = fotoDataUrl;
    final bytesFoto = decodificarFotoDataUrl(foto);
    final hayFoto = bytesFoto != null || (foto != null && foto.isNotEmpty);

    Widget areaImagen;
    if (bytesFoto != null) {
      areaImagen = Image.memory(
        bytesFoto,
        height: 170,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else if (foto != null && foto.isNotEmpty) {
      areaImagen = Image.network(
        resolverUrlFotoBicicleta(foto),
        height: 170,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _placeholderImagen('No se pudo cargar la imagen'),
      );
    } else {
      areaImagen = _placeholderImagen('Sin imagen');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            titulo,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: ColoresUbb.azulApp,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: ColoresUbb.superficieAzulSuave,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: hayFoto && foto != null && foto.isNotEmpty
                ? () => _mostrarImagenAmpliada(context, foto)
                : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColoresUbb.borde),
              ),
              child: Stack(
                children: [
                  areaImagen,
                  if (hayFoto && foto != null && foto.isNotEmpty)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Tooltip(
                        message: 'Ampliar imagen',
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.56),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.open_in_full,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  if (hayFoto && mostrarAcciones)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onQuitar,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (mostrarAcciones) const SizedBox(height: 6),
        if (errorText != null)
          Text(
            errorText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
          ),
        if (errorText != null && mostrarAcciones) const SizedBox(height: 6),
        if (hayFoto && mostrarAcciones)
          Text(
            'Toca la X para quitar la imagen.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColoresUbb.textoSecundario,
                ),
          ),
        if (mostrarAcciones) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCamara,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Tomar foto'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGaleria,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Subir foto'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _placeholderImagen(String texto) {
    return Container(
      height: 170,
      width: double.infinity,
      color: Colors.white,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined,
              size: 42, color: ColoresUbb.textoSecundario),
          const SizedBox(height: 8),
          Text(
            texto,
            style: const TextStyle(color: ColoresUbb.textoSecundario),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarImagenAmpliada(
    BuildContext context,
    String fotoReferencia,
  ) async {
    await mostrarFotoBicicletaAmpliada(context, fotoReferencia);
  }
}
