import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/features/acceso/application/gestion_manual_vm.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/modelos/rol_usuario.dart';
import 'package:ubbike/shared/utils/identidad.dart';
import 'package:ubbike/shared/utils/limites_foto.dart';
import 'package:ubbike/shared/utils/opciones_bicicleta.dart';
import 'package:ubbike/shared/utils/sesion_ui_utils.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/features/bicicletas/presentation/formulario_bicicleta_usuario.dart';
import 'package:ubbike/features/acceso/presentation/vista_escaner_qr_guardia.dart';

const _alturaCampoGestionManual = 56.0;
const _paddingCampoGestionManual =
    EdgeInsets.symmetric(horizontal: 14, vertical: 14);

InputDecoration _decoracionCampoGestionManual({
  required String labelText,
  String? hintText,
  String? errorText,
  String? helperText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool alignLabelWithHint = false,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    helperText: helperText,
    helperMaxLines: 2,
    helperStyle: const TextStyle(color: ColoresUbb.textoSecundario),
    errorMaxLines: 3,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    alignLabelWithHint: alignLabelWithHint,
    contentPadding: _paddingCampoGestionManual,
    constraints: const BoxConstraints(minHeight: _alturaCampoGestionManual),
  );
}

class VistaGestionManualGuardia extends ConsumerStatefulWidget {
  const VistaGestionManualGuardia({super.key});

  @override
  ConsumerState<VistaGestionManualGuardia> createState() =>
      _VistaGestionManualGuardiaState();
}

class _VistaGestionManualGuardiaState
    extends ConsumerState<VistaGestionManualGuardia> {
  GestionManualVm get vm => ref.read(gestionManualVmProvider);
  final formKeyGestionManual = GlobalKey<FormState>();

  final nombreController = TextEditingController();
  final correoController = TextEditingController();
  final rutController = TextEditingController();
  final comentarioController = TextEditingController();
  final bicicletaDescripcionController = TextEditingController();
  final bicicletaMarcaController = TextEditingController();
  final bicicletaModeloController = TextEditingController();
  final bicicletaColorController = TextEditingController();
  final bicicletaAroController = TextEditingController();
  final bicicletaNumeroSerieController = TextEditingController();
  final correoFocusNode = FocusNode();
  final rutFocusNode = FocusNode();
  final nombreFocusNode = FocusNode();
  final comentarioFocusNode = FocusNode();
  final bicicletaDescripcionFocusNode = FocusNode();
  final bicicletaMarcaFocusNode = FocusNode();
  final bicicletaModeloFocusNode = FocusNode();
  final bicicletaNumeroSerieFocusNode = FocusNode();
  String? fotoBicicletaManual;
  String? errorFotoBicicletaManual;
  String operacion = 'INGRESO';
  Timer? temporizadorBusqueda;
  CoincidenciaManualApp? coincidenciaManual;
  List<BicicleteroApp> bicicleteros = [];
  String? bicicletaSeleccionadaId;
  String? bicicleteroSeleccionadoId;
  String? errorBusquedaManual;
  String? errorBicicleteros;
  bool buscandoCoincidencia = false;
  bool busquedaRealizada = false;
  bool nombreAutocompletado = false;
  bool actualizandoCampos = false;
  bool registrando = false;
  bool cargandoBicicleteros = false;

  bool get _retiroBloqueadoPorRegistroParcial =>
      coincidenciaManual?.usuario.registroParcial == true &&
      operacion == 'RETIRO';

  bool get _debeMostrarOperacion =>
      bicicletaSeleccionadaId != null ||
      busquedaRealizada ||
      bicicletaDescripcionController.text.trim().isNotEmpty;

  bool get _requiereDatosUsuarioNuevo =>
      busquedaRealizada && coincidenciaManual == null;

  @override
  void initState() {
    super.initState();
    correoController.addListener(_programarBusquedaCoincidencia);
    rutController.addListener(_programarBusquedaCoincidencia);
    bicicletaDescripcionController.addListener(_actualizarOperacionVisible);
    correoFocusNode.addListener(_actualizarAyudaCampo);
    rutFocusNode.addListener(_actualizarAyudaCampo);
    nombreFocusNode.addListener(_actualizarAyudaCampo);
    comentarioFocusNode.addListener(_actualizarAyudaCampo);
    bicicletaDescripcionFocusNode.addListener(_actualizarAyudaCampo);
    bicicletaMarcaFocusNode.addListener(_actualizarAyudaCampo);
    bicicletaModeloFocusNode.addListener(_actualizarAyudaCampo);
    bicicletaNumeroSerieFocusNode.addListener(_actualizarAyudaCampo);
    _cargarBicicleteros();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recuperarFotoManualPerdida();
    });
  }

  Future<void> _recuperarFotoManualPerdida() async {
    if (kIsWeb) {
      return;
    }

    try {
      final respuesta = await ImagePicker().retrieveLostData();
      if (respuesta.isEmpty) {
        return;
      }

      final archivos = respuesta.files;
      final archivo = archivos != null && archivos.isNotEmpty
          ? archivos.first
          : respuesta.file;
      if (archivo == null) {
        return;
      }

      final bytes = await archivo.readAsBytes();
      final mime = detectarMimeDesdeBytes(bytes);
      if (!mimesFotoPermitidos.contains(mime)) {
        return;
      }

      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      if (dataUrl.length > maxFotoDataUrlLength) {
        return;
      }

      if (mounted) {
        setState(() {
          fotoBicicletaManual = dataUrl;
          errorFotoBicicletaManual = null;
        });
        context.mostrarInfo('Recuperamos la foto que tomaste antes.');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    temporizadorBusqueda?.cancel();
    correoController.removeListener(_programarBusquedaCoincidencia);
    rutController.removeListener(_programarBusquedaCoincidencia);
    bicicletaDescripcionController.removeListener(_actualizarOperacionVisible);
    correoFocusNode.removeListener(_actualizarAyudaCampo);
    rutFocusNode.removeListener(_actualizarAyudaCampo);
    nombreFocusNode.removeListener(_actualizarAyudaCampo);
    comentarioFocusNode.removeListener(_actualizarAyudaCampo);
    bicicletaDescripcionFocusNode.removeListener(_actualizarAyudaCampo);
    bicicletaMarcaFocusNode.removeListener(_actualizarAyudaCampo);
    bicicletaModeloFocusNode.removeListener(_actualizarAyudaCampo);
    bicicletaNumeroSerieFocusNode.removeListener(_actualizarAyudaCampo);
    correoFocusNode.dispose();
    rutFocusNode.dispose();
    nombreFocusNode.dispose();
    comentarioFocusNode.dispose();
    bicicletaDescripcionFocusNode.dispose();
    bicicletaMarcaFocusNode.dispose();
    bicicletaModeloFocusNode.dispose();
    bicicletaNumeroSerieFocusNode.dispose();
    nombreController.dispose();
    correoController.dispose();
    rutController.dispose();
    comentarioController.dispose();
    bicicletaDescripcionController.dispose();
    bicicletaMarcaController.dispose();
    bicicletaModeloController.dispose();
    bicicletaColorController.dispose();
    bicicletaAroController.dispose();
    bicicletaNumeroSerieController.dispose();
    super.dispose();
  }

  void _actualizarOperacionVisible() {
    if (actualizandoCampos) {
      return;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _limpiarNombreSiAutocompletado() {
    if (nombreAutocompletado) {
      nombreController.clear();
      nombreAutocompletado = false;
    }
  }

  void _actualizarAyudaCampo() {
    if (mounted) {
      setState(() {});
    }
  }

  String? _ayudaSiActivo(FocusNode focusNode, String texto) {
    return focusNode.hasFocus ? texto : null;
  }

  Future<void> _cargarBicicleteros() async {
    setState(() {
      cargandoBicicleteros = true;
      errorBicicleteros = null;
    });

    try {
      final datos = await vm.listarBicicleteros();
      if (!mounted) {
        return;
      }
      setState(() {
        bicicleteros = datos;
        if (!bicicleteros.any((item) => item.id == bicicleteroSeleccionadoId)) {
          bicicleteroSeleccionadoId = null;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        bicicleteros = [];
        bicicleteroSeleccionadoId = null;
        errorBicicleteros = 'No se pudieron cargar los bicicleteros.';
      });
    } finally {
      if (mounted) {
        setState(() => cargandoBicicleteros = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolSesion = rolSesionActual(context);
    final requiereBicicletero =
        rolSesion != RolUsuario.guardia && operacion == 'INGRESO';
    final retiroRegistroParcialBloqueado = _retiroBloqueadoPorRegistroParcial;
    final mostrarOperacion = _debeMostrarOperacion;
    final bicicletaSeleccionada =
        _buscarBicicletaSeleccionada(bicicletaSeleccionadaId);
    final creandoBicicletaNueva = bicicletaSeleccionadaId == null;
    final bicicletasRegistradas =
        coincidenciaManual?.bicicletas ?? const <BicicletaApp>[];
    final mostrandoBicicletaRegistrada =
        bicicletasRegistradas.isNotEmpty && bicicletaSeleccionadaId != null;

    return ListView(
      children: [
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: formKeyGestionManual,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (mostrarOperacion) ...[
                    _IndicadorOperacionManual(
                      operacion: operacion,
                      autodetectada: bicicletaSeleccionadaId != null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (requiereBicicletero) ...[
                    _SelectorBicicleteroManual(
                      bicicleteros: bicicleteros,
                      value: bicicleteroSeleccionadoId,
                      cargando: cargandoBicicleteros,
                      error: errorBicicleteros,
                      onChanged: (valor) =>
                          setState(() => bicicleteroSeleccionadoId = valor),
                      onRecargar: _cargarBicicleteros,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Datos de usuario',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: ColoresUbb.azulNoche,
                        ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: correoController,
                    focusNode: correoFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    decoration: _decoracionCampoGestionManual(
                      labelText: 'Correo institucional',
                      helperText: _ayudaSiActivo(
                        correoFocusNode,
                        'Usa correo institucional cuando corresponda.',
                      ),
                    ),
                    validator: (valor) => _validarCorreoGestionManual(
                      valor,
                      rutController.text,
                      requiereCorreo: _requiereDatosUsuarioNuevo,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: rutController,
                    focusNode: rutFocusNode,
                    autocorrect: false,
                    inputFormatters: [RutInputFormatter()],
                    decoration: _decoracionCampoGestionManual(
                      labelText: 'RUT',
                      helperText: _ayudaSiActivo(
                        rutFocusNode,
                        'Escribe el guion; los puntos se agregan solos.',
                      ),
                    ),
                    validator: (valor) => _validarRutGestionManual(
                      valor,
                      requerido: _requiereDatosUsuarioNuevo,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nombreController,
                    focusNode: nombreFocusNode,
                    readOnly: coincidenciaManual != null,
                    textCapitalization: TextCapitalization.words,
                    decoration: _decoracionCampoGestionManual(
                      labelText: 'Nombre',
                      hintText: coincidenciaManual != null
                          ? null
                          : 'Nombre y apellido de la persona',
                      helperText: coincidenciaManual == null
                          ? _ayudaSiActivo(
                              nombreFocusNode,
                              'Nombre real para identificar a la persona.',
                            )
                          : null,
                    ),
                    onChanged: (_) => nombreAutocompletado = false,
                    validator: (valor) => _validarNombreGestionManual(
                      valor,
                      requerido: _requiereDatosUsuarioNuevo,
                    ),
                  ),
                  _EstadoBusquedaManual(
                    buscando: buscandoCoincidencia,
                    error: errorBusquedaManual,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Datos de bicicleta',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: ColoresUbb.azulNoche,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (bicicletaSeleccionadaId != null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ChipEstado(
                              texto: 'Bicicleta registrada',
                              color: ColoresUbb.azulApp,
                            ),
                          ),
                        )
                      else if (busquedaRealizada)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ChipEstado(
                              texto: 'Bicicleta no registrada',
                              color: ColoresUbb.azulApp,
                            ),
                          ),
                        ),
                      if (mostrandoBicicletaRegistrada) ...[
                        if (bicicletasRegistradas.length == 1 &&
                            bicicletaSeleccionada != null)
                          _DetalleBicicletaRegistrada(
                            bicicleta: bicicletaSeleccionada,
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return DropdownAnclado<String>(
                                key: ValueKey(
                                  bicicletaSeleccionadaId ?? 'sin-bici',
                                ),
                                isExpanded: true,
                                borderRadius: BorderRadius.circular(16),
                                menuMaxHeight: 300,
                                value: bicicletaSeleccionadaId,
                                decoration: _decoracionCampoGestionManual(
                                  labelText: 'Bicicleta registrada',
                                ),
                                items: bicicletasRegistradas
                                    .map(
                                      (bicicleta) => DropdownMenuItem(
                                        value: bicicleta.id,
                                        child: Text(
                                          _resumenBicicleta(bicicleta),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (valor) =>
                                    _seleccionarBicicleta(valor),
                              );
                            },
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: UnconstrainedBox(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: ColoresUbb.azulApp,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _usarBicicletaNoRegistrada,
                              icon: const Icon(
                                Icons.pedal_bike_outlined,
                                size: 16,
                              ),
                              label: const Text('Registrar otra bicicleta'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextFormField(
                        controller: bicicletaDescripcionController,
                        focusNode: bicicletaDescripcionFocusNode,
                        readOnly: bicicletaSeleccionadaId != null &&
                            operacion == 'RETIRO',
                        onChanged: (_) => _detacharBicicletaSiEditada(),
                        decoration: _decoracionCampoGestionManual(
                          labelText: 'Descripción',
                          helperText: _ayudaSiActivo(
                            bicicletaDescripcionFocusNode,
                            'Nombre breve para reconocer la bicicleta.',
                          ),
                        ),
                        validator: (valor) => creandoBicicletaNueva
                            ? validarDescripcionBicicleta(valor)
                            : _validarDescripcionBicicletaManual(
                                valor,
                                false,
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: bicicletaMarcaController,
                              focusNode: bicicletaMarcaFocusNode,
                              readOnly: bicicletaSeleccionadaId != null &&
                                  operacion == 'RETIRO',
                              onChanged: (_) => _detacharBicicletaSiEditada(),
                              decoration: _decoracionCampoGestionManual(
                                labelText: 'Marca',
                                helperText: _ayudaSiActivo(
                                  bicicletaMarcaFocusNode,
                                  'Usa la marca visible o registrada.',
                                ),
                              ),
                              validator: (valor) =>
                                  _validarCampoRequeridoConFormato(
                                valor,
                                requerido: creandoBicicletaNueva,
                                mensajeRequerido: 'Ingresa la marca.',
                                validarFormato: validarMarcaBicicleta,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: bicicletaModeloController,
                              focusNode: bicicletaModeloFocusNode,
                              readOnly: bicicletaSeleccionadaId != null &&
                                  operacion == 'RETIRO',
                              onChanged: (_) => _detacharBicicletaSiEditada(),
                              decoration: _decoracionCampoGestionManual(
                                labelText: 'Modelo',
                                helperText: _ayudaSiActivo(
                                  bicicletaModeloFocusNode,
                                  'Usa el modelo visible o una referencia breve.',
                                ),
                              ),
                              validator: (valor) =>
                                  _validarCampoRequeridoConFormato(
                                valor,
                                requerido: creandoBicicletaNueva,
                                mensajeRequerido: 'Ingresa el modelo.',
                                validarFormato: validarModeloBicicleta,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CampoColorBicicleta(
                              key: ValueKey(
                                'color-manual-${bicicletaSeleccionadaId ?? 'nuevo'}',
                              ),
                              valorInicial: bicicletaColorController.text,
                              habilitado: !(bicicletaSeleccionadaId != null &&
                                  operacion == 'RETIRO'),
                              helperText:
                                  'Color principal o combinacion simple.',
                              onChanged: (valor) {
                                bicicletaColorController.text = valor;
                                _detacharBicicletaSiEditada();
                              },
                              validator: (valor) =>
                                  _validarCampoRequeridoConFormato(
                                valor,
                                requerido: creandoBicicletaNueva,
                                mensajeRequerido: 'Ingresa el color.',
                                validarFormato: validarColorBicicleta,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FormField<String>(
                              key: ValueKey(
                                'aro-manual-${bicicletaSeleccionadaId ?? 'nuevo'}-${bicicletaAroController.text}',
                              ),
                              initialValue: normalizarAroBicicleta(
                                    bicicletaAroController.text,
                                  ) ??
                                  '',
                              validator: (valor) => _validarAroGestionManual(
                                valor,
                                requerido: creandoBicicletaNueva,
                              ),
                              builder: (field) {
                                final bloqueado =
                                    bicicletaSeleccionadaId != null &&
                                        operacion == 'RETIRO';
                                final valor = field.value ?? '';

                                return DropdownAnclado<String>(
                                  value: valor,
                                  decoration: _decoracionCampoGestionManual(
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
                                  onChanged: bloqueado
                                      ? null
                                      : (valor) {
                                          final seleccionado = valor ?? '';
                                          field.didChange(seleccionado);
                                          bicicletaAroController.text =
                                              seleccionado;
                                          _detacharBicicletaSiEditada();
                                        },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: bicicletaNumeroSerieController,
                        focusNode: bicicletaNumeroSerieFocusNode,
                        readOnly: bicicletaSeleccionadaId != null &&
                            operacion == 'RETIRO',
                        onChanged: (_) => _detacharBicicletaSiEditada(),
                        decoration: _decoracionCampoGestionManual(
                          labelText: 'N° de serie',
                          helperText: _ayudaSiActivo(
                            bicicletaNumeroSerieFocusNode,
                            'Codigo del marco, sin espacios.',
                          ),
                        ),
                        validator: (valor) => _validarCampoRequeridoConFormato(
                          valor,
                          requerido: creandoBicicletaNueva,
                          mensajeRequerido: 'Ingresa el numero de serie.',
                          validarFormato: validarNumeroSerieBicicleta,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectorFotoBicicleta(
                        fotoDataUrl: bicicletaSeleccionada?.fotoUrl ??
                            fotoBicicletaManual,
                        onCamara: creandoBicicletaNueva
                            ? () => _seleccionarFotoBicicletaManual(
                                  ImageSource.camera,
                                )
                            : () {},
                        onGaleria: creandoBicicletaNueva
                            ? () => _seleccionarFotoBicicletaManual(
                                  ImageSource.gallery,
                                )
                            : () {},
                        onQuitar: !creandoBicicletaNueva ||
                                fotoBicicletaManual == null
                            ? null
                            : () => setState(
                                  () {
                                    fotoBicicletaManual = null;
                                    errorFotoBicicletaManual = null;
                                  },
                                ),
                        errorText: errorFotoBicicletaManual,
                        mostrarAcciones: creandoBicicletaNueva,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: comentarioController,
                    focusNode: comentarioFocusNode,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Comentario opcional del guardia',
                      hintText: 'Ej: Usuario posee U-Lock',
                      alignLabelWithHint: true,
                      helperText: _ayudaSiActivo(
                        comentarioFocusNode,
                        'Solo observaciones operativas si corresponde.',
                      ),
                    ),
                    validator: (valor) =>
                        _validarCampoOpcionalGestionManual(valor, 600),
                  ),
                  if (retiroRegistroParcialBloqueado) ...[
                    const SizedBox(height: 12),
                    const _CajaBusquedaManual(
                      icono: Icons.lock_outline,
                      color: ColoresUbb.rojoInstitucional,
                      children: [
                        Text(
                          'Retiro bloqueado: el usuario debe completar su registro desde el correo de activacion antes de retirar la bicicleta.',
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: registrando ||
                                  buscandoCoincidencia ||
                                  retiroRegistroParcialBloqueado
                              ? null
                              : () => _registrarManual(),
                          child: registrando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Registrar ${operacion == 'INGRESO' ? 'ingreso' : 'retiro'}',
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColoresUbb.rojoInstitucional,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: registrando ||
                                  buscandoCoincidencia ||
                                  retiroRegistroParcialBloqueado
                              ? null
                              : () => _mostrarRechazoManual(context),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Rechazar ${operacion == 'INGRESO' ? 'ingreso' : 'retiro'}',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: registrando ? null : _cancelarAccionManual,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancelar acción'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _programarBusquedaCoincidencia() {
    if (actualizandoCampos) {
      return;
    }

    temporizadorBusqueda?.cancel();
    final correo = correoController.text.trim();
    final rut = rutController.text.trim();

    if (correo.isEmpty && rut.isEmpty) {
      _limpiarNombreSiAutocompletado();
      setState(() {
        buscandoCoincidencia = false;
        busquedaRealizada = false;
        coincidenciaManual = null;
        bicicletaSeleccionadaId = null;
        fotoBicicletaManual = null;
        errorFotoBicicletaManual = null;
        errorBusquedaManual = null;
      });
      return;
    }

    if (!vm.datoBusquedaSuficiente(correo, rut)) {
      _limpiarNombreSiAutocompletado();
      setState(() {
        buscandoCoincidencia = false;
        busquedaRealizada = false;
        coincidenciaManual = null;
        bicicletaSeleccionadaId = null;
        fotoBicicletaManual = null;
        errorFotoBicicletaManual = null;
        errorBusquedaManual = null;
      });
      return;
    }

    setState(() {
      buscandoCoincidencia = true;
      busquedaRealizada = false;
      coincidenciaManual = null;
      bicicletaSeleccionadaId = null;
      fotoBicicletaManual = null;
      errorFotoBicicletaManual = null;
      errorBusquedaManual = null;
    });
    _limpiarNombreSiAutocompletado();

    temporizadorBusqueda = Timer(
      const Duration(milliseconds: 550),
      () => _buscarCoincidencia(correo, rut),
    );
  }

  Future<void> _buscarCoincidencia(String correo, String rut) async {
    try {
      final coincidencia = await vm.buscarCoincidencia(
        correo: correo,
        rut: rut,
      );

      if (!mounted ||
          correoController.text.trim() != correo ||
          rutController.text.trim() != rut) {
        return;
      }

      if (coincidencia == null) {
        _limpiarNombreSiAutocompletado();
        setState(() {
          buscandoCoincidencia = false;
          busquedaRealizada = true;
          coincidenciaManual = null;
          bicicletaSeleccionadaId = null;
          fotoBicicletaManual = null;
          errorFotoBicicletaManual = null;
          bicicletaDescripcionController.clear();
          bicicletaMarcaController.clear();
          bicicletaModeloController.clear();
          bicicletaColorController.clear();
          bicicletaAroController.clear();
          bicicletaNumeroSerieController.clear();
          errorBusquedaManual = null;
        });
        return;
      }

      _aplicarCoincidenciaManual(coincidencia);
    } on ExcepcionApi catch (error) {
      if (!mounted) return;
      _limpiarNombreSiAutocompletado();
      setState(() {
        buscandoCoincidencia = false;
        busquedaRealizada = true;
        coincidenciaManual = null;
        bicicletaSeleccionadaId = null;
        fotoBicicletaManual = null;
        errorFotoBicicletaManual = null;
        errorBusquedaManual = error.mensaje;
      });
    }
  }

  void _aplicarCoincidenciaManual(
    CoincidenciaManualApp coincidencia,
  ) {
    actualizandoCampos = true;
    nombreController.text = coincidencia.usuario.nombre;
    correoController.text = coincidencia.usuario.correo;
    rutController.text = coincidencia.usuario.rut ?? rutController.text.trim();
    actualizandoCampos = false;
    nombreAutocompletado = true;

    final preferida =
        vm.bicicletaPreferidaAutodetectada(coincidencia.bicicletas);

    setState(() {
      buscandoCoincidencia = false;
      busquedaRealizada = true;
      coincidenciaManual = coincidencia;
      bicicletaSeleccionadaId = preferida?.id;
      fotoBicicletaManual = null;
      errorFotoBicicletaManual = null;
      errorBusquedaManual = null;

      if (preferida == null) {
        operacion = 'INGRESO';
        bicicletaDescripcionController.clear();
        bicicletaMarcaController.clear();
        bicicletaModeloController.clear();
        bicicletaColorController.clear();
        bicicletaAroController.clear();
        bicicletaNumeroSerieController.clear();
        return;
      }

      _cargarDatosBicicleta(preferida);
      operacion = vm.operacionParaBicicleta(preferida);
    });
  }

  BicicletaApp? _buscarBicicletaSeleccionada(String? bicicletaId) {
    if (bicicletaId == null) {
      return null;
    }

    for (final bicicleta
        in coincidenciaManual?.bicicletas ?? const <BicicletaApp>[]) {
      if (bicicleta.id == bicicletaId) {
        return bicicleta;
      }
    }

    return null;
  }

  void _seleccionarBicicleta(String? bicicletaId) {
    final bicicleta = _buscarBicicletaSeleccionada(bicicletaId);

    setState(() {
      bicicletaSeleccionadaId = bicicleta?.id;
      if (bicicleta != null) {
        fotoBicicletaManual = null;
        errorFotoBicicletaManual = null;
        _cargarDatosBicicleta(bicicleta);
        operacion = vm.operacionParaBicicleta(bicicleta);
      }
    });
  }

  void _cargarDatosBicicleta(BicicletaApp bicicleta) {
    bicicletaDescripcionController.text = bicicleta.descripcion;
    bicicletaMarcaController.text = bicicleta.marca ?? '';
    bicicletaModeloController.text = bicicleta.modelo ?? '';
    bicicletaColorController.text =
        normalizarColorBicicleta(bicicleta.color) ?? bicicleta.color ?? '';
    bicicletaAroController.text =
        normalizarAroBicicleta(bicicleta.aro) ?? bicicleta.aro ?? '';
    bicicletaNumeroSerieController.text = bicicleta.numeroSerie ?? '';
  }

  Future<void> _seleccionarFotoBicicletaManual(ImageSource source) async {
    try {
      final imagen = await ImagePicker().pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (imagen == null) {
        return;
      }

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
            'La foto es muy pesada. Elige una imagen mas liviana.',
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          fotoBicicletaManual = dataUrl;
          errorFotoBicicletaManual = null;
        });
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError('No se pudo cargar la foto.');
      }
    }
  }

  void _detacharBicicletaSiEditada() {
    if (actualizandoCampos ||
        bicicletaSeleccionadaId == null ||
        operacion == 'RETIRO') {
      return;
    }
    setState(() {
      bicicletaSeleccionadaId = null;
      operacion = 'INGRESO';
    });
  }

  void _usarBicicletaNoRegistrada() {
    setState(() {
      operacion = 'INGRESO';
      bicicletaSeleccionadaId = null;
      fotoBicicletaManual = null;
      errorFotoBicicletaManual = null;
      bicicletaDescripcionController.clear();
      bicicletaMarcaController.clear();
      bicicletaModeloController.clear();
      bicicletaColorController.clear();
      bicicletaAroController.clear();
      bicicletaNumeroSerieController.clear();
    });
  }

  String _resumenBicicleta(BicicletaApp bicicleta) {
    final estado = bicicleta.dentroBicicletero
        ? 'Dentro${bicicleta.bicicleteroActualNombre == null ? '' : ' - ${bicicleta.bicicleteroActualNombre}'}'
        : 'Fuera';
    final activa = bicicleta.activa ? 'Activa' : 'Inactiva';
    return '${bicicleta.descripcion} | $activa | $estado';
  }

  void _mostrarRechazoManual(BuildContext context) {
    if (!_validarFormularioGestionManual()) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SheetDenegacion(
        onConfirmar: (motivo) => _registrarManual(
          denegar: true,
          motivo: motivo,
        ),
      ),
    );
  }

  bool _validarFormularioGestionManual() {
    final crearBicicletaNueva = bicicletaSeleccionadaId == null;
    final requiereBicicletero =
        rolSesionActual(context) != RolUsuario.guardia &&
            operacion == 'INGRESO';

    if (registrando) {
      return false;
    }
    if (buscandoCoincidencia) {
      context
          .mostrarError('Espera a que termine la busqueda de coincidencias.');
      return false;
    }
    if (formKeyGestionManual.currentState?.validate() != true) {
      return false;
    }
    if (crearBicicletaNueva && fotoBicicletaManual == null) {
      setState(() {
        errorFotoBicicletaManual = 'Toma o sube una foto de la bicicleta.';
      });
      return false;
    }
    if (requiereBicicletero && bicicleteroSeleccionadoId == null) {
      context.mostrarError('Selecciona el bicicletero del ingreso.');
      return false;
    }

    return true;
  }

  Future<bool> _registrarManual({
    bool denegar = false,
    String? motivo,
  }) async {
    final correo = correoController.text.trim();
    final rut = rutController.text.trim();
    final crearBicicletaNueva = bicicletaSeleccionadaId == null;

    if (!_validarFormularioGestionManual()) {
      return false;
    }

    setState(() => registrando = true);

    try {
      final movimiento = await vm.registrarManual(
        nombre: nombreController.text.trim(),
        correo: correo,
        rut: rut,
        bicicletaId: bicicletaSeleccionadaId,
        bicicleteroId:
            operacion == 'INGRESO' ? bicicleteroSeleccionadoId : null,
        tipo: operacion,
        comentario: comentarioController.text.trim(),
        bicicletaDescripcion: bicicletaDescripcionController.text.trim(),
        bicicletaMarca: bicicletaMarcaController.text.trim(),
        bicicletaModelo: bicicletaModeloController.text.trim(),
        bicicletaColor:
            normalizarColorBicicleta(bicicletaColorController.text.trim()) ??
                bicicletaColorController.text.trim(),
        bicicletaAro:
            normalizarAroBicicleta(bicicletaAroController.text.trim()) ??
                bicicletaAroController.text.trim(),
        bicicletaNumeroSerie: bicicletaNumeroSerieController.text.trim(),
        bicicletaFotoUrl: fotoBicicletaManual,
        crearBicicletaNueva: crearBicicletaNueva,
        denegar: denegar,
        motivo: motivo,
      );

      if (mounted) {
        _limpiarFormularioGestionManual();
        final tipoMovimiento =
            movimiento.tipo == 'INGRESO' ? 'Ingreso' : 'Retiro';
        context.mostrarExito(
          '$tipoMovimiento ${denegar ? 'rechazado' : 'registrado'} para ${movimiento.usuarioNombre}',
        );
      }
      return true;
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => registrando = false);
      }
    }
  }

  void _cancelarAccionManual() {
    _limpiarFormularioGestionManual();
    context.mostrarInfo('Acción cancelada');
  }

  void _limpiarFormularioGestionManual() {
    temporizadorBusqueda?.cancel();
    actualizandoCampos = true;
    nombreController.clear();
    correoController.clear();
    rutController.clear();
    comentarioController.clear();
    bicicletaDescripcionController.clear();
    bicicletaMarcaController.clear();
    bicicletaModeloController.clear();
    bicicletaColorController.clear();
    bicicletaAroController.clear();
    bicicletaNumeroSerieController.clear();
    actualizandoCampos = false;

    setState(() {
      operacion = 'INGRESO';
      buscandoCoincidencia = false;
      busquedaRealizada = false;
      nombreAutocompletado = false;
      coincidenciaManual = null;
      bicicletaSeleccionadaId = null;
      bicicleteroSeleccionadoId = null;
      fotoBicicletaManual = null;
      errorFotoBicicletaManual = null;
      errorBusquedaManual = null;
    });
  }
}

String? _validarNombreGestionManual(
  String? valor, {
  bool requerido = false,
}) {
  final nombre = valor?.trim() ?? '';

  if (nombre.isEmpty) {
    return requerido ? 'Ingresa el nombre de la persona.' : null;
  }
  if (nombre.length < 3) {
    return 'Debe tener al menos 3 caracteres.';
  }
  if (nombre.length > 120) {
    return 'Maximo 120 caracteres.';
  }
  return null;
}

String? _validarCorreoGestionManual(
  String? valor,
  String rutActual, {
  bool requiereCorreo = false,
}) {
  final correo = valor?.trim() ?? '';
  final rut = rutActual.trim();

  if (requiereCorreo && correo.isEmpty) {
    return 'Ingresa correo para crear el registro parcial.';
  }
  if (correo.isEmpty && rut.isEmpty) {
    return 'Ingresa correo o RUT.';
  }
  if (correo.isEmpty) {
    return null;
  }
  if (correo.length > 160) {
    return 'Maximo 160 caracteres.';
  }

  final correoValido = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  if (!correoValido.hasMatch(correo)) {
    return 'Ingresa un correo valido. Ej: usuario@ubiobio.cl';
  }
  return null;
}

String? _validarRutGestionManual(
  String? valor, {
  bool requerido = false,
}) {
  final rut = valor?.trim() ?? '';
  if (requerido && rut.isEmpty) {
    return 'Ingresa RUT para crear el registro parcial.';
  }
  if (rut.isEmpty) {
    return null;
  }
  if (rut.length > 20) {
    return 'Maximo 20 caracteres.';
  }

  final rutLimpio = rut.replaceAll('.', '').replaceAll('-', '');
  if (rutLimpio.length < 7) {
    return 'Ingresa un RUT valido.';
  }
  return null;
}

String? _validarCampoRequeridoConFormato(
  String? valor, {
  required bool requerido,
  required String mensajeRequerido,
  required String? Function(String?) validarFormato,
}) {
  final texto = valor?.trim() ?? '';
  if (requerido && texto.isEmpty) {
    return mensajeRequerido;
  }
  if (!requerido && texto.isEmpty) {
    return null;
  }
  return validarFormato(valor);
}

String? _validarAroGestionManual(
  String? valor, {
  required bool requerido,
}) {
  final texto = valor?.trim() ?? '';
  if (requerido && texto.isEmpty) {
    return 'Ingresa el aro.';
  }
  if (!requerido && texto.isEmpty) {
    return null;
  }
  if (normalizarAroBicicleta(texto) == null) {
    return 'Ingresa un aro valido.';
  }
  return null;
}

String? _validarDescripcionBicicletaManual(
  String? valor,
  bool requerida,
) {
  final texto = valor?.trim() ?? '';
  if (!requerida && texto.isEmpty) {
    return null;
  }
  if (texto.isEmpty) {
    return 'Ingresa una descripcion.';
  }
  if (texto.length < 3) {
    return 'Debe tener al menos 3 caracteres.';
  }
  if (texto.length > 255) {
    return 'Maximo 255 caracteres.';
  }
  return null;
}

String? _validarCampoOpcionalGestionManual(String? valor, int maximo) {
  final texto = valor?.trim() ?? '';
  if (texto.length > maximo) {
    return 'Maximo $maximo caracteres.';
  }
  return null;
}

class _SelectorBicicleteroManual extends StatelessWidget {
  const _SelectorBicicleteroManual({
    required this.bicicleteros,
    required this.value,
    required this.cargando,
    required this.error,
    required this.onChanged,
    required this.onRecargar,
  });

  final List<BicicleteroApp> bicicleteros;
  final String? value;
  final bool cargando;
  final String? error;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRecargar;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const _CajaBusquedaManual(
        icono: Icons.hourglass_empty_outlined,
        color: ColoresUbb.azulApp,
        children: [
          Text('Cargando bicicleteros disponibles...'),
        ],
      );
    }

    if (error != null) {
      return _CajaBusquedaManual(
        icono: Icons.error_outline,
        color: ColoresUbb.rojoInstitucional,
        children: [
          Text(error!),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRecargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    if (bicicleteros.isEmpty) {
      return const _CajaBusquedaManual(
        icono: Icons.info_outline,
        color: ColoresUbb.azulApp,
        children: [
          Text('No hay bicicleteros activos para registrar el ingreso.'),
        ],
      );
    }

    final valorSeguro =
        bicicleteros.any((bicicletero) => bicicletero.id == value)
            ? value
            : null;

    return DropdownAnclado<String>(
      value: valorSeguro,
      borderRadius: BorderRadius.circular(16),
      menuMaxHeight: 320,
      decoration: _decoracionCampoGestionManual(
        labelText: 'Bicicletero del ingreso',
        prefixIcon: const Icon(Icons.local_parking_outlined),
      ),
      items: bicicleteros
          .map(
            (bicicletero) => DropdownMenuItem<String>(
              value: bicicletero.id,
              child: Text(
                '${bicicletero.nombre} | ${bicicletero.cuposDisponibles} cupos',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _IndicadorOperacionManual extends StatelessWidget {
  const _IndicadorOperacionManual({
    required this.operacion,
    required this.autodetectada,
  });

  final String operacion;
  final bool autodetectada;

  @override
  Widget build(BuildContext context) {
    final esIngreso = operacion == 'INGRESO';
    final color = esIngreso ? ColoresUbb.exito : ColoresUbb.azulApp;
    final textoBase = esIngreso ? 'Ingreso' : 'Retiro';
    final textoOperacion = autodetectada ? '$textoBase detectado' : textoBase;

    return Align(
      alignment: Alignment.centerLeft,
      child: ChipEstado(
        texto: textoOperacion,
        color: color,
      ),
    );
  }
}

class _DetalleBicicletaRegistrada extends StatelessWidget {
  const _DetalleBicicletaRegistrada({
    required this.bicicleta,
  });

  final BicicletaApp bicicleta;

  @override
  Widget build(BuildContext context) {
    final estado = bicicleta.activa ? 'Activa' : 'Inactiva';
    final bicicletero = bicicleta.dentroBicicletero
        ? bicicleta.bicicleteroActualNombre ?? 'Bicicletero no informado'
        : 'No registra ingreso activo';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CampoDetalleBicicletaRegistrada(
          etiqueta: 'Bicicleta',
          valor: bicicleta.descripcion,
        ),
        const SizedBox(height: 10),
        _CampoDetalleBicicletaRegistrada(
          etiqueta: 'Estado',
          valor: estado,
        ),
        const SizedBox(height: 10),
        _CampoDetalleBicicletaRegistrada(
          etiqueta: 'Bicicletero actual',
          valor: bicicletero,
        ),
      ],
    );
  }
}

class _CampoDetalleBicicletaRegistrada extends StatelessWidget {
  const _CampoDetalleBicicletaRegistrada({
    required this.etiqueta,
    required this.valor,
  });

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: _decoracionCampoGestionManual(
        labelText: etiqueta,
      ),
      child: Text(
        valor,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ColoresUbb.azulNoche,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _EstadoBusquedaManual extends StatelessWidget {
  const _EstadoBusquedaManual({
    required this.buscando,
    required this.error,
  });

  final bool buscando;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (buscando) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(
                child: Text('Buscando coincidencias en la base de datos...')),
          ],
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          error!,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColoresUbb.rojoInstitucional,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _CajaBusquedaManual extends StatelessWidget {
  const _CajaBusquedaManual({
    required this.icono,
    required this.color,
    required this.children,
  });

  final IconData icono;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
