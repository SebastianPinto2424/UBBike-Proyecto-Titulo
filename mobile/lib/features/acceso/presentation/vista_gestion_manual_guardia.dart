import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ubbike/core/modelos/rol_usuario.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/features/acceso/application/gestion_manual_vm.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:ubbike/features/acceso/presentation/campos_gestion_manual.dart';
import 'package:ubbike/features/acceso/presentation/dialogo_resultado_movimiento.dart';
import 'package:ubbike/features/acceso/presentation/encabezado_operacion_manual.dart';
import 'package:ubbike/features/acceso/presentation/seccion_bicicleta_manual.dart';
import 'package:ubbike/features/acceso/presentation/secciones_gestion_manual.dart';
import 'package:ubbike/features/acceso/presentation/sheet_denegacion_qr.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/servicios/captura_fotos.dart';
import 'package:ubbike/shared/utils/sesion_ui_utils.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';

class VistaGestionManualGuardia extends ConsumerStatefulWidget {
  const VistaGestionManualGuardia({super.key, this.onMovimientoRegistrado});

  final VoidCallback? onMovimientoRegistrado;

  @override
  ConsumerState<VistaGestionManualGuardia> createState() =>
      _VistaGestionManualGuardiaState();
}

class _VistaGestionManualGuardiaState
    extends ConsumerState<VistaGestionManualGuardia> {
  GestionManualVm get vm => ref.read(gestionManualVmProvider);
  final formKeyGestionManual = GlobalKey<FormState>();

  final campos = CamposGestionManual();
  final _capturaFotos = CapturaFotos();
  String? fotoBicicletaManual;
  String? errorFotoBicicletaManual;
  String operacion = 'INGRESO';
  Timer? temporizadorBusqueda;
  CoincidenciaManualApp? coincidenciaManual;
  String? bicicletaSeleccionadaId;
  String? bicicleteroSeleccionadoId;
  String? errorBusquedaManual;
  bool buscandoCoincidencia = false;
  bool busquedaRealizada = false;
  bool nombreAutocompletado = false;
  bool actualizandoCampos = false;
  bool registrando = false;

  bool get _retiroBloqueadoPorRegistroParcial =>
      coincidenciaManual?.usuario.registroParcial == true &&
      operacion == 'RETIRO';

  bool get _debeMostrarOperacion =>
      bicicletaSeleccionadaId != null ||
      busquedaRealizada ||
      campos.descripcion.text.trim().isNotEmpty;

  bool get _requiereDatosUsuarioNuevo =>
      busquedaRealizada && coincidenciaManual == null;

  @override
  void initState() {
    super.initState();
    campos.correo.addListener(_programarBusquedaCoincidencia);
    campos.rut.addListener(_programarBusquedaCoincidencia);
    campos.descripcion.addListener(_redibujar);
    campos.escucharFocos(_redibujar);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recuperarFotoManualPerdida();
    });
  }

  Future<void> _recuperarFotoManualPerdida() async {
    try {
      final dataUrl = (await _capturaFotos.recuperarPerdida())?.dataUrl;
      if (dataUrl == null || !mounted) {
        return;
      }
      setState(() {
        fotoBicicletaManual = dataUrl;
        errorFotoBicicletaManual = null;
      });
      context.mostrarInfo('Recuperamos la foto que tomaste antes.');
    } catch (_) {}
  }

  @override
  void dispose() {
    temporizadorBusqueda?.cancel();
    campos.correo.removeListener(_programarBusquedaCoincidencia);
    campos.rut.removeListener(_programarBusquedaCoincidencia);
    campos.descripcion.removeListener(_redibujar);
    campos.dejarDeEscucharFocos(_redibujar);
    campos.dispose();
    super.dispose();
  }

  void _redibujar() {
    if (actualizandoCampos) {
      return;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _limpiarNombreSiAutocompletado() {
    if (nombreAutocompletado) {
      campos.nombre.clear();
      nombreAutocompletado = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolSesion = rolSesionActual(context);
    final requiereBicicletero =
        rolSesion != RolUsuario.guardia && operacion == 'INGRESO';
    final retiroRegistroParcialBloqueado = _retiroBloqueadoPorRegistroParcial;
    final mostrarOperacion = _debeMostrarOperacion;

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
                  EncabezadoOperacionManual(
                    operacion: operacion,
                    mostrarOperacion: mostrarOperacion,
                    autodetectada: bicicletaSeleccionadaId != null,
                    requiereBicicletero: requiereBicicletero,
                    bicicleteroId: bicicleteroSeleccionadoId,
                    onBicicletero: (valor) =>
                        setState(() => bicicleteroSeleccionadoId = valor),
                  ),
                  SeccionUsuarioManual(
                    campos: campos,
                    usuarioEncontrado: coincidenciaManual != null,
                    requiereDatosNuevos: _requiereDatosUsuarioNuevo,
                    buscando: buscandoCoincidencia,
                    errorBusqueda: errorBusquedaManual,
                    onNombreEditado: () => nombreAutocompletado = false,
                  ),
                  const SizedBox(height: 12),
                  SeccionBicicletaManual(
                    campos: campos,
                    operacion: operacion,
                    bicicletaSeleccionadaId: bicicletaSeleccionadaId,
                    busquedaRealizada: busquedaRealizada,
                    bicicletasRegistradas:
                        coincidenciaManual?.bicicletas ?? const [],
                    fotoNueva: fotoBicicletaManual,
                    errorFoto: errorFotoBicicletaManual,
                    onSeleccionarBicicleta: _seleccionarBicicleta,
                    onUsarNoRegistrada: _usarBicicletaNoRegistrada,
                    onCampoEditado: _detacharBicicletaSiEditada,
                    onElegirFoto: _seleccionarFotoBicicletaManual,
                    onQuitarFoto: () => setState(() {
                      fotoBicicletaManual = null;
                      errorFotoBicicletaManual = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  AccionesGestionManual(
                    campos: campos,
                    operacion: operacion,
                    retiroBloqueado: retiroRegistroParcialBloqueado,
                    registrando: registrando,
                    buscando: buscandoCoincidencia,
                    onRegistrar: _registrarDesdeFormulario,
                    onRechazar: () => _mostrarRechazoManual(context),
                    onCancelar: _cancelarAccionManual,
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
    final anterior = coincidenciaManual;
    if (anterior != null) {
      actualizandoCampos = true;
      final corrigio = campos.soltarIdentidadDe(anterior.usuario);
      actualizandoCampos = false;
      if (!corrigio) return;
    }

    temporizadorBusqueda?.cancel();
    final correo = campos.correo.text.trim();
    final rut = campos.rut.text.trim();

    if ((correo.isEmpty && rut.isEmpty) ||
        !vm.datoBusquedaSuficiente(correo, rut)) {
      _limpiarNombreSiAutocompletado();
      _reiniciarBusqueda(buscando: false, realizada: false);
      return;
    }

    _reiniciarBusqueda(buscando: true, realizada: false);
    _limpiarNombreSiAutocompletado();

    temporizadorBusqueda = Timer(
      const Duration(milliseconds: 550),
      () => _buscarCoincidencia(correo, rut),
    );
  }

  void _reiniciarBusqueda({
    required bool buscando,
    required bool realizada,
    String? error,
  }) {
    setState(() {
      buscandoCoincidencia = buscando;
      busquedaRealizada = realizada;
      coincidenciaManual = null;
      bicicletaSeleccionadaId = null;
      fotoBicicletaManual = null;
      errorFotoBicicletaManual = null;
      errorBusquedaManual = error;
    });
  }

  Future<void> _buscarCoincidencia(String correo, String rut) async {
    try {
      final coincidencia = await vm.buscarCoincidencia(
        correo: correo,
        rut: rut,
      );

      if (!mounted ||
          campos.correo.text.trim() != correo ||
          campos.rut.text.trim() != rut) {
        return;
      }

      if (coincidencia == null) {
        _limpiarNombreSiAutocompletado();
        campos.limpiarBicicleta();
        _reiniciarBusqueda(buscando: false, realizada: true);
        return;
      }

      _aplicarCoincidenciaManual(coincidencia);
    } on ExcepcionApi catch (error) {
      if (!mounted) return;
      _limpiarNombreSiAutocompletado();
      _reiniciarBusqueda(
        buscando: false,
        realizada: true,
        error: error.mensaje,
      );
    }
  }

  void _aplicarCoincidenciaManual(
    CoincidenciaManualApp coincidencia,
  ) {
    actualizandoCampos = true;
    campos.nombre.text = coincidencia.usuario.nombre;
    campos.correo.text = coincidencia.usuario.correo;
    campos.rut.text = coincidencia.usuario.rut ?? campos.rut.text.trim();
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
        campos.limpiarBicicleta();
        return;
      }

      campos.cargarBicicleta(preferida);
      operacion = vm.operacionParaBicicleta(preferida);
    });
  }

  BicicletaApp? _buscarBicicletaSeleccionada(String? bicicletaId) =>
      coincidenciaManual?.bicicletas
          .where((bicicleta) => bicicleta.id == bicicletaId)
          .firstOrNull;

  void _seleccionarBicicleta(String? bicicletaId) {
    final bicicleta = _buscarBicicletaSeleccionada(bicicletaId);

    setState(() {
      bicicletaSeleccionadaId = bicicleta?.id;
      if (bicicleta != null) {
        fotoBicicletaManual = null;
        errorFotoBicicletaManual = null;
        campos.cargarBicicleta(bicicleta);
        operacion = vm.operacionParaBicicleta(bicicleta);
      }
    });
  }

  Future<void> _seleccionarFotoBicicletaManual(ImageSource source) async {
    try {
      final foto = await _capturaFotos.elegir(
        context,
        source,
        calidad: 72,
        ladoMaximo: 1200,
      );
      if (foto == null || !mounted) {
        return;
      }
      final dataUrl = foto.dataUrl;
      if (dataUrl == null) {
        context.mostrarError(foto.error ?? 'No se pudo cargar la foto.');
        return;
      }
      setState(() {
        fotoBicicletaManual = dataUrl;
        errorFotoBicicletaManual = null;
      });
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
      campos.limpiarBicicleta();
    });
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
        esIngreso: operacion == 'INGRESO',
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
          .mostrarError('Espera a que termine la búsqueda de coincidencias.');
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

  Future<void> _registrarDesdeFormulario() async {
    if (!_validarFormularioGestionManual()) {
      return;
    }
    final error = await _registrarManual();
    if (error != null && mounted) {
      context.mostrarError(error);
    }
  }

  Future<String?> _registrarManual({
    bool denegar = false,
    String? motivo,
  }) async {
    setState(() => registrando = true);

    try {
      final movimiento = await vm.registrarManual(
        campos.solicitud(
          tipo: operacion,
          bicicletaId: bicicletaSeleccionadaId,
          bicicleteroId:
              operacion == 'INGRESO' ? bicicleteroSeleccionadoId : null,
          fotoUrl: fotoBicicletaManual,
          denegar: denegar,
          motivo: motivo,
        ),
      );

      if (mounted) {
        _limpiarFormularioGestionManual();
        unawaited(avisarMovimientoRegistrado(
          context,
          confirmado: !denegar,
          esIngreso: movimiento.tipo == 'INGRESO',
          persona: movimiento.usuarioNombre,
          alTerminar: widget.onMovimientoRegistrado,
        ));
      }
      return null;
    } on ExcepcionApi catch (error) {
      return error.mensaje;
    } catch (_) {
      return 'No se pudo conectar con el servidor.';
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
    campos.limpiarTodo();
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
