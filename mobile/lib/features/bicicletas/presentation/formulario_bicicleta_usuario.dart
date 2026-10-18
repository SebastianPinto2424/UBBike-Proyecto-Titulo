import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/features/bicicletas/data/borrador_bicicleta.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/servicios/captura_fotos.dart';
import 'package:ubbike/shared/utils/limites_foto.dart';
import 'package:ubbike/shared/utils/opciones_bicicleta.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/selector_foto.dart';
import 'package:ubbike/shared/widgets/estilos_formulario.dart';
import 'package:ubbike/shared/widgets/campo_color_bicicleta.dart';
import 'package:ubbike/features/bicicletas/application/bicicletas_vm.dart';

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
  final capturaFotos = CapturaFotos();
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

  String? error;
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
          'se cerró mientras tomabas una foto). ¿Quieres continuarlo?',
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
    try {
      _aplicarFoto(await capturaFotos.recuperarPerdida());
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
      if (!mounted) {
        return;
      }
      _aplicarFoto(
        await capturaFotos.elegir(
          context,
          source,
          calidad: 68,
          ladoMaximo: 900,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = 'No se pudo cargar la foto.');
      }
    }
  }

  void _aplicarFoto(FotoPreparada? foto) {
    if (foto == null || !mounted) {
      return;
    }
    final dataUrl = foto.dataUrl;
    if (dataUrl == null) {
      setState(() => error = foto.error ?? 'No se pudo cargar la foto.');
      return;
    }
    setState(() {
      error = null;
      fotoSeleccionada = dataUrl;
      fotoModificada = true;
    });
  }

  Future<void> _guardar() async {
    if (formKeyBicicleta.currentState?.validate() != true || guardando) {
      return;
    }

    final descripcion = descripcionController.text.trim();
    final color = normalizarColorBicicleta(colorTexto) ?? '';
    final numeroSerie = numeroSerieController.text.trim().toUpperCase();

    setState(() {
      guardando = true;
      error = null;
    });

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
    } on ExcepcionApi catch (excepcion) {
      if (mounted) {
        setState(() => error = excepcion.mensaje);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'No se pudo guardar. Revisa tu conexión.');
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
                    'Código del marco, sin espacios.',
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
                  return SelectorFoto(
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
              if (error != null) ...[
                ErrorFormulario(mensaje: error!),
                const SizedBox(height: 12),
              ],
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
