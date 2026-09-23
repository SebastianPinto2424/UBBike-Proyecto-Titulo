import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/features/bicicletas/application/bicicletas_vm.dart';
import 'package:ubbike/features/bicicletas/data/borrador_bicicleta.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/utils/limites_foto.dart';
import 'package:ubbike/shared/utils/opciones_bicicleta.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/utils/utiles_comun.dart';

const _alturaCampoFormularioBicicleta = 56.0;
const _paddingCampoFormularioBicicleta =
    EdgeInsets.symmetric(horizontal: 14, vertical: 14);

InputDecoration decoracionCampoFormularioBicicleta({
  required String labelText,
  String? errorText,
  String? helperText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    errorText: errorText,
    helperText: helperText,
    helperMaxLines: 2,
    helperStyle: const TextStyle(color: ColoresUbb.textoSecundario),
    errorMaxLines: 3,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: _paddingCampoFormularioBicicleta,
    constraints:
        const BoxConstraints(minHeight: _alturaCampoFormularioBicicleta),
  );
}

class FormularioBicicletaSheet extends ConsumerStatefulWidget {
  const FormularioBicicletaSheet({
    super.key,
    required this.bicicleta,
  });

  final BicicletaApp? bicicleta;

  @override
  ConsumerState<FormularioBicicletaSheet> createState() =>
      _FormularioBicicletaSheetState();
}

class _FormularioBicicletaSheetState
    extends ConsumerState<FormularioBicicletaSheet> {
  BicicletasVm get vm => ref.read(bicicletasVmProvider);
  final imagePicker = ImagePicker();
  final formKeyBicicleta = GlobalKey<FormState>();
  late final TextEditingController descripcionController;
  late final TextEditingController marcaController;
  late final TextEditingController modeloController;
  late final TextEditingController numeroSerieController;
  final descripcionFocusNode = FocusNode();
  final marcaFocusNode = FocusNode();
  final modeloFocusNode = FocusNode();
  final numeroSerieFocusNode = FocusNode();
  late String colorTexto;
  String? aroSeleccionado;
  late String? fotoSeleccionada;
  late bool activar;
  bool guardando = false;
  bool fotoModificada = false;
  int _versionRestaurada = 0;

  @override
  void initState() {
    super.initState();
    final bicicleta = widget.bicicleta;
    descripcionController =
        TextEditingController(text: bicicleta?.descripcion ?? '');
    marcaController = TextEditingController(text: bicicleta?.marca ?? '');
    modeloController = TextEditingController(text: bicicleta?.modelo ?? '');
    colorTexto =
        normalizarColorBicicleta(bicicleta?.color) ?? bicicleta?.color ?? '';
    aroSeleccionado = normalizarAroBicicleta(bicicleta?.aro);
    numeroSerieController =
        TextEditingController(text: bicicleta?.numeroSerie ?? '');
    fotoSeleccionada = bicicleta?.fotoUrl;
    activar = bicicleta?.activa ?? true;
    descripcionFocusNode.addListener(_actualizarAyudaCampo);
    marcaFocusNode.addListener(_actualizarAyudaCampo);
    modeloFocusNode.addListener(_actualizarAyudaCampo);
    numeroSerieFocusNode.addListener(_actualizarAyudaCampo);

    if (bicicleta == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ofrecerRecuperarBorrador();
      });
    }
  }

  @override
  void dispose() {
    descripcionFocusNode.removeListener(_actualizarAyudaCampo);
    marcaFocusNode.removeListener(_actualizarAyudaCampo);
    modeloFocusNode.removeListener(_actualizarAyudaCampo);
    numeroSerieFocusNode.removeListener(_actualizarAyudaCampo);
    descripcionFocusNode.dispose();
    marcaFocusNode.dispose();
    modeloFocusNode.dispose();
    numeroSerieFocusNode.dispose();
    descripcionController.dispose();
    marcaController.dispose();
    modeloController.dispose();
    numeroSerieController.dispose();
    super.dispose();
  }

  void _actualizarAyudaCampo() {
    if (mounted) {
      setState(() {});
    }
  }

  String? _ayudaSiActivo(FocusNode focusNode, String texto) {
    return focusNode.hasFocus ? texto : null;
  }

  Future<void> _ofrecerRecuperarBorrador() async {
    final borrador = await leerBorradorBicicleta();
    if (borrador == null || !mounted) {
      return;
    }

    final continuar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registro sin terminar'),
        content: const Text(
          'Tenías un registro de bicicleta sin terminar (por ejemplo, la app '
          'se cerró mientras tomabas una foto). ¿Querés continuarlo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Descartar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (continuar != true) {
      await borrarBorradorBicicleta();
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      descripcionController.text = borrador.descripcion;
      marcaController.text = borrador.marca;
      modeloController.text = borrador.modelo;
      colorTexto = borrador.color;
      aroSeleccionado = borrador.aro;
      numeroSerieController.text = borrador.numeroSerie;
      activar = borrador.activar;
      _versionRestaurada++;
    });

    await _recuperarFotoPerdida();
  }

  Future<void> _recuperarFotoPerdida() async {
    if (kIsWeb) {
      return;
    }

    try {
      final respuesta = await imagePicker.retrieveLostData();
      if (respuesta.isEmpty) {
        return;
      }

      final archivos = respuesta.files;
      if (archivos != null && archivos.isNotEmpty) {
        await _procesarFoto(archivos.first);
      }
    } catch (_) {}
  }

  Future<void> _guardarBorradorActual() async {
    await guardarBorradorBicicleta(
      BorradorBicicleta(
        descripcion: descripcionController.text,
        marca: marcaController.text,
        modelo: modeloController.text,
        color: colorTexto,
        aro: aroSeleccionado,
        numeroSerie: numeroSerieController.text,
        activar: activar,
      ),
    );
  }

  Future<void> _seleccionarFoto(ImageSource source) async {
    try {
      if (widget.bicicleta == null) {
        await _guardarBorradorActual();
      }

      final imagen = await imagePicker.pickImage(
        source: source,
        imageQuality: 68,
        maxWidth: 900,
        maxHeight: 900,
      );

      if (imagen == null) {
        return;
      }

      await _procesarFoto(imagen);
    } catch (_) {
      if (mounted) {
        context.mostrarError('No se pudo cargar la foto.');
      }
    }
  }

  Future<void> _procesarFoto(XFile imagen) async {
    try {
      final bytes = await imagen.readAsBytes();
      final mime = detectarMimeDesdeBytes(bytes);

      if (!mimesFotoPermitidos.contains(mime)) {
        if (mounted) {
          context.mostrarError('La foto debe ser JPG, PNG o WEBP.');
        }
        return;
      }

      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      if (dataUrl.length > maxFotoDataUrlLength) {
        if (mounted) {
          context.mostrarError(
              'La foto es muy pesada. Elige una imagen más liviana.');
        }
        return;
      }

      if (mounted) {
        setState(() {
          fotoSeleccionada = dataUrl;
          fotoModificada = true;
        });
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError('No se pudo cargar la foto.');
      }
    }
  }

  Future<void> _guardar() async {
    if (formKeyBicicleta.currentState?.validate() != true || guardando) {
      return;
    }

    final descripcion = descripcionController.text.trim();
    final color = normalizarColorBicicleta(colorTexto) ?? '';
    final numeroSerie = numeroSerieController.text.trim().toUpperCase();

    setState(() => guardando = true);

    try {
      final bicicleta = widget.bicicleta;
      if (bicicleta == null) {
        await vm.crear(
          descripcion: descripcion,
          marca: marcaController.text.trim(),
          modelo: modeloController.text.trim(),
          color: color,
          aro: aroSeleccionado ?? '',
          numeroSerie: numeroSerie,
          fotoUrl: fotoSeleccionada,
          activar: activar,
        );
        await borrarBorradorBicicleta();
      } else {
        await vm.actualizar(
          bicicletaId: bicicleta.id,
          descripcion: descripcion,
          marca: marcaController.text.trim(),
          modelo: modeloController.text.trim(),
          color: color,
          aro: aroSeleccionado ?? '',
          numeroSerie: numeroSerie,
          fotoUrl: fotoSeleccionada,
          actualizarFoto: fotoModificada,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError('No se pudo guardar. Revisa tu conexión.');
      }
    } finally {
      if (mounted) {
        setState(() => guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bicicleta = widget.bicicleta;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: formKeyBicicleta,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                bicicleta == null ? 'Registrar bicicleta' : 'Editar bicicleta',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: descripcionController,
                focusNode: descripcionFocusNode,
                decoration: decoracionCampoFormularioBicicleta(
                  labelText: 'Descripción',
                  helperText: _ayudaSiActivo(
                    descripcionFocusNode,
                    'Nombre breve para reconocer la bicicleta.',
                  ),
                ),
                textInputAction: TextInputAction.next,
                validator: validarDescripcionBicicleta,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: marcaController,
                      focusNode: marcaFocusNode,
                      decoration: decoracionCampoFormularioBicicleta(
                        labelText: 'Marca',
                        helperText: _ayudaSiActivo(
                          marcaFocusNode,
                          'Usa la marca visible o registrada.',
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: validarMarcaBicicleta,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: modeloController,
                      focusNode: modeloFocusNode,
                      decoration: decoracionCampoFormularioBicicleta(
                        labelText: 'Modelo',
                        helperText: _ayudaSiActivo(
                          modeloFocusNode,
                          'Usa el modelo visible o una referencia breve.',
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: validarModeloBicicleta,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CampoColorBicicleta(
                      key: ValueKey('color-$_versionRestaurada'),
                      valorInicial: colorTexto,
                      habilitado: !guardando,
                      helperText: 'Color principal o combinacion simple.',
                      onChanged: (valor) => colorTexto = valor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FormField<String>(
                      key: ValueKey('aro-$_versionRestaurada'),
                      initialValue: aroSeleccionado ?? '',
                      validator: validarAroBicicleta,
                      builder: (field) {
                        return DropdownAnclado<String>(
                          value: field.value ?? '',
                          decoration: decoracionCampoFormularioBicicleta(
                            labelText: 'Aro',
                            errorText: field.errorText,
                            helperText: 'Selecciona la medida del aro.',
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('Seleccionar'),
                            ),
                            ...arosBicicleta.map(
                              (aro) => DropdownMenuItem<String>(
                                value: aro,
                                child: Text(aro),
                              ),
                            ),
                          ],
                          onChanged: guardando
                              ? null
                              : (valor) {
                                  final seleccionado = valor ?? '';
                                  field.didChange(seleccionado);
                                  setState(
                                    () => aroSeleccionado = seleccionado.isEmpty
                                        ? null
                                        : seleccionado,
                                  );
                                },
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: numeroSerieController,
                focusNode: numeroSerieFocusNode,
                decoration: decoracionCampoFormularioBicicleta(
                  labelText: 'Número de serie',
                  helperText: _ayudaSiActivo(
                    numeroSerieFocusNode,
                    'Codigo del marco, sin espacios.',
                  ),
                ),
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
                validator: validarNumeroSerieBicicleta,
              ),
              const SizedBox(height: 12),
              FormField<String?>(
                initialValue: fotoSeleccionada,
                validator: (_) {
                  final foto = fotoSeleccionada?.trim() ?? '';
                  return foto.isEmpty ? 'Toma o sube una foto.' : null;
                },
                builder: (field) {
                  return SelectorFotoBicicleta(
                    fotoDataUrl: fotoSeleccionada,
                    errorText: field.errorText,
                    onCamara: () async {
                      await _seleccionarFoto(ImageSource.camera);
                      field.didChange(fotoSeleccionada);
                    },
                    onGaleria: () async {
                      await _seleccionarFoto(ImageSource.gallery);
                      field.didChange(fotoSeleccionada);
                    },
                    onQuitar: fotoSeleccionada == null
                        ? null
                        : () {
                            setState(() {
                              fotoSeleccionada = null;
                              fotoModificada = true;
                            });
                            field.didChange(null);
                          },
                  );
                },
              ),
              if (bicicleta == null) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: activar,
                  onChanged: guardando
                      ? null
                      : (valor) => setState(() => activar = valor ?? false),
                  title: const Text('Usar como bicicleta activa'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: guardando ? null : _guardar,
                icon: guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(guardando ? 'Guardando' : 'Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CampoColorBicicleta extends StatefulWidget {
  const CampoColorBicicleta({
    super.key,
    required this.valorInicial,
    required this.habilitado,
    required this.onChanged,
    this.helperText,
    this.validator,
  });

  final String valorInicial;
  final bool habilitado;
  final ValueChanged<String> onChanged;
  final String? helperText;
  final FormFieldValidator<String>? validator;

  @override
  State<CampoColorBicicleta> createState() => _CampoColorBicicletaState();
}

class _CampoColorBicicletaState extends State<CampoColorBicicleta> {
  FocusNode? _focusNode;

  @override
  void dispose() {
    _focusNode?.removeListener(_actualizarFoco);
    super.dispose();
  }

  void _sincronizarFocusNode(FocusNode focusNode) {
    if (_focusNode == focusNode) {
      return;
    }
    _focusNode?.removeListener(_actualizarFoco);
    _focusNode = focusNode..addListener(_actualizarFoco);
  }

  void _actualizarFoco() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.valorInicial),
      displayStringForOption: (opcion) => opcion,
      optionsBuilder: (texto) => sugerirColoresBicicleta(texto.text),
      onSelected: widget.onChanged,
      fieldViewBuilder: (
        context,
        controller,
        focusNode,
        onFieldSubmitted,
      ) {
        _sincronizarFocusNode(focusNode);

        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.habilitado,
          decoration: decoracionCampoFormularioBicicleta(
            labelText: 'Color',
            helperText: focusNode.hasFocus ? widget.helperText : null,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          onChanged: widget.onChanged,
          validator: widget.validator ?? validarColorBicicleta,
        );
      },
    );
  }
}

class SelectorFotoBicicleta extends StatelessWidget {
  const SelectorFotoBicicleta({
    super.key,
    required this.fotoDataUrl,
    required this.onCamara,
    required this.onGaleria,
    required this.onQuitar,
    this.mostrarAcciones = true,
    this.errorText,
  });

  final String? fotoDataUrl;
  final VoidCallback onCamara;
  final VoidCallback onGaleria;
  final VoidCallback? onQuitar;
  final bool mostrarAcciones;
  final String? errorText;

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
            'Imagen bicicleta',
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
