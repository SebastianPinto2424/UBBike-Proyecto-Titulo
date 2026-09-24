import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/features/incidencias/application/incidencias_vm.dart';

import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/incidencias/data/incidencia_modelos.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/widgets/boton_con_espera.dart';
import 'package:ubbike/shared/widgets/chip_estado.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';
import 'package:ubbike/shared/widgets/tarjeta_accion.dart';
import 'package:ubbike/shared/widgets/central_widgets.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/lista_con_filtros.dart';
import 'package:ubbike/features/acceso/presentation/solicitud_guardia_widgets.dart';
import 'package:ubbike/shared/utils/utiles_comun.dart';

import 'package:ubbike/features/bicicletas/presentation/vista_bicicletas_usuario.dart';
import 'package:ubbike/shared/widgets/filtros_widgets.dart';

class VistaIncidencias extends ConsumerStatefulWidget {
  const VistaIncidencias({
    super.key,
    required this.mostrarReportante,
    required this.puedeGestionar,
    this.permitirBicicletaPropia = false,
    this.gestionGuardia = false,
    this.gestionCentral = false,
  });

  final bool mostrarReportante;
  final bool puedeGestionar;
  final bool permitirBicicletaPropia;
  final bool gestionGuardia;
  final bool gestionCentral;

  @override
  ConsumerState<VistaIncidencias> createState() => _VistaIncidenciasState();
}

class _VistaIncidenciasState extends ConsumerState<VistaIncidencias> {
  final busquedaController = TextEditingController();

  IncidenciasVm get vm => ref.read(incidenciasVmProvider.notifier);

  ({bool gestionGuardia, bool permitirBicicletaPropia}) get _argsFormulario => (
        gestionGuardia: widget.gestionGuardia,
        permitirBicicletaPropia: widget.permitirBicicletaPropia,
      );

  @override
  void dispose() {
    busquedaController.dispose();
    super.dispose();
  }

  void _recargar() {
    vm.recargar();
  }

  void _programarBusqueda() {
    setState(() {});
    vm.buscar(busquedaController.text);
  }

  void _limpiarFiltros() {
    busquedaController.clear();
    vm.limpiarFiltros();
  }

  Future<bool> _crearIncidencia({
    required String bicicleteroId,
    required String tipo,
    required String descripcion,
    String? bicicletaId,
  }) async {
    try {
      await vm.crear(
        bicicleteroId: bicicleteroId,
        tipo: tipo,
        descripcion: descripcion,
        bicicletaId: bicicletaId,
      );

      if (mounted) {
        context.mostrarExito('Incidencia registrada correctamente');
      }
      return true;
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
      return false;
    } catch (_) {
      if (mounted) {
        context.mostrarError('No se pudo conectar con el backend');
      }
      return false;
    }
  }

  Future<void> _abrirFormulario() async {
    final datosFormulario = ref
        .read(datosFormularioIncidenciaProvider(_argsFormulario))
        .valueOrNull;
    if (datosFormulario == null) {
      return;
    }
    if (datosFormulario.bicicleteros.isEmpty) {
      context.mostrarError(
        'No hay un bicicletero disponible para asociar el reporte.',
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _SheetRegistrarIncidencia(
        bicicleteros: datosFormulario.bicicleteros,
        bicicletas: datosFormulario.bicicletas,
        permitirBicicletaPropia: widget.permitirBicicletaPropia,
        onEnviar: _crearIncidencia,
      ),
    );
  }

  Future<void> _actualizarEstado(
      IncidenciaApp incidencia, String estado) async {
    final respuesta = await _pedirRespuestaGestion(
      incidencia: incidencia,
      estado: estado,
    );

    if (respuesta == null && estado != 'EN_REVISION') {
      return;
    }

    try {
      await vm.actualizarEstado(
        incidenciaId: incidencia.id,
        estado: estado,
        respuesta: respuesta,
      );

      if (mounted) {
        context.mostrarExito(
            'Incidencia ${_etiquetaEstadoIncidencia(estado).toLowerCase()}');
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError('No se pudo conectar con el backend');
      }
    }
  }

  Future<void> _recordar(IncidenciaApp incidencia) async {
    try {
      await vm.recordar(incidenciaId: incidencia.id);

      if (mounted) {
        context.mostrarExito('Recordatorio enviado');
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError('No se pudo conectar con el backend');
      }
    }
  }

  Future<String?> _pedirRespuestaGestion({
    required IncidenciaApp incidencia,
    required String estado,
  }) async {
    if (estado == 'EN_REVISION') {
      return '';
    }

    return showDialog<String?>(
      context: context,
      builder: (_) => _DialogoRespuestaGestion(
        incidencia: incidencia,
        estado: estado,
        respuestaInicial: incidencia.respuesta ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(incidenciasVersionProvider, (_, __) {
      if (mounted) {
        vm.recargar();
      }
    });
    final estadoIncidencias = ref.watch(incidenciasVmProvider);
    final filtros = ref.watch(filtrosIncidenciasProvider);
    final datosFormulario =
        ref.watch(datosFormularioIncidenciaProvider(_argsFormulario));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListaConFiltros(
        onRefrescar: vm.refrescar,
        cabecera: [
          _FiltrosIncidencias(
            estado: filtros.estado,
            tipo: filtros.tipo,
            busquedaController: busquedaController,
            onLimpiar: _limpiarFiltros,
            onEstado: vm.cambiarEstado,
            onTipo: vm.cambiarTipo,
            onBuscar: _programarBusqueda,
            onRegistrar: datosFormulario.isLoading ? null : _abrirFormulario,
          ),
        ],
        contenido: _contenidoIncidencias(estadoIncidencias),
      ),
    );
  }

  Widget _contenidoIncidencias(AsyncValue<List<IncidenciaApp>> estado) {
    final ultimoDato = estado.valueOrNull;

    if (estado.isLoading && ultimoDato == null) {
      return const SliverCargando();
    }

    if (estado.hasError && ultimoDato == null) {
      return SliverToBoxAdapter(
        child: TarjetaAccion(
          icono: Icons.error_outline,
          titulo: 'No se pudieron cargar incidencias',
          detalle: 'Revisa tu conexión y toca para reintentar.',
          color: ColoresUbb.rojoInstitucional,
          onTap: _recargar,
        ),
      );
    }

    final incidencias = ultimoDato ?? const <IncidenciaApp>[];

    if (incidencias.isEmpty) {
      return const SliverEspacioRestante(
        child: EstadoLista(
          icono: Icons.report_problem_outlined,
          titulo: 'Sin incidencias',
          detalle: 'Cuando exista un reporte operativo aparecerá aquí.',
        ),
      );
    }

    return SliverList.list(
      children: [
        if (vm.desactualizado)
          const ListTile(
            leading: Icon(Icons.cloud_off_outlined),
            title: Text('Datos sin actualizar. Desliza para reintentar.'),
          ),
        ...incidencias.map(
          (incidencia) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TarjetaIncidencia(
              incidencia: incidencia,
              mostrarReportante: widget.mostrarReportante,
              puedeGestionar: widget.puedeGestionar,
              gestionGuardia: widget.gestionGuardia,
              mostrarRecordar: !widget.mostrarReportante,
              onActualizarEstado: (estado) =>
                  _actualizarEstado(incidencia, estado),
              onRecordar: () => _recordar(incidencia),
              onEsperaCumplida: vm.refrescar,
            ),
          ),
        ),
        if (vm.hayMas)
          OutlinedButton(
            onPressed: vm.cargandoMas ? null : vm.cargarMas,
            child:
                Text(vm.cargandoMas ? 'Cargando…' : 'Cargar más incidencias'),
          ),
      ],
    );
  }
}

class _SheetRegistrarIncidencia extends StatefulWidget {
  const _SheetRegistrarIncidencia({
    required this.bicicleteros,
    required this.bicicletas,
    required this.permitirBicicletaPropia,
    required this.onEnviar,
  });

  final List<BicicleteroApp> bicicleteros;
  final List<BicicletaApp> bicicletas;
  final bool permitirBicicletaPropia;
  final Future<bool> Function({
    required String bicicleteroId,
    required String tipo,
    required String descripcion,
    String? bicicletaId,
  }) onEnviar;

  @override
  State<_SheetRegistrarIncidencia> createState() =>
      _SheetRegistrarIncidenciaState();
}

class _SheetRegistrarIncidenciaState extends State<_SheetRegistrarIncidencia> {
  final formKeyIncidencia = GlobalKey<FormState>();
  final descripcionController = TextEditingController();
  BicicleteroApp? bicicleteroSeleccionado;
  BicicletaApp? bicicletaSeleccionada;
  String tipoSeleccionado = 'OTRO';
  bool enviando = false;

  @override
  void initState() {
    super.initState();
    bicicleteroSeleccionado =
        widget.bicicleteros.isEmpty ? null : widget.bicicleteros.first;
  }

  @override
  void dispose() {
    descripcionController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final bicicletero = bicicleteroSeleccionado;
    final descripcion = descripcionController.text.trim();

    if (bicicletero == null ||
        formKeyIncidencia.currentState?.validate() != true ||
        enviando) {
      return;
    }

    setState(() => enviando = true);
    final ok = await widget.onEnviar(
      bicicleteroId: bicicletero.id,
      tipo: tipoSeleccionado,
      descripcion: descripcion,
      bicicletaId: bicicletaSeleccionada?.id,
    );

    if (!mounted) {
      return;
    }
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registrar incidencia',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Completa el reporte para que el equipo pueda gestionarlo.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ColoresUbb.textoSecundario,
                  ),
            ),
            const SizedBox(height: 12),
            Form(
              key: formKeyIncidencia,
              child: _FormularioIncidencia(
                cargando: false,
                enviando: enviando,
                bicicleteros: widget.bicicleteros,
                bicicletas: widget.bicicletas,
                bicicleteroSeleccionado: bicicleteroSeleccionado,
                bicicletaSeleccionada: bicicletaSeleccionada,
                tipoSeleccionado: tipoSeleccionado,
                descripcionController: descripcionController,
                permitirBicicletaPropia: widget.permitirBicicletaPropia,
                onBicicletero: (valor) =>
                    setState(() => bicicleteroSeleccionado = valor),
                onBicicleta: (valor) =>
                    setState(() => bicicletaSeleccionada = valor),
                onTipo: (valor) => setState(() => tipoSeleccionado = valor),
                onEnviar: _enviar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoRespuestaGestion extends StatefulWidget {
  const _DialogoRespuestaGestion({
    required this.incidencia,
    required this.estado,
    required this.respuestaInicial,
  });

  final IncidenciaApp incidencia;
  final String estado;
  final String respuestaInicial;

  @override
  State<_DialogoRespuestaGestion> createState() =>
      _DialogoRespuestaGestionState();
}

class _DialogoRespuestaGestionState extends State<_DialogoRespuestaGestion> {
  final formKeyRespuestaGestion = GlobalKey<FormState>();
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.respuestaInicial);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _guardar() {
    if (formKeyRespuestaGestion.currentState?.validate() != true) {
      return;
    }

    final texto = controller.text.trim();
    Navigator.of(context).pop(texto);
  }

  @override
  Widget build(BuildContext context) {
    final descartar = widget.estado == 'DESCARTADA';
    final color = descartar ? ColoresUbb.rojoInstitucional : ColoresUbb.azulApp;
    final incidencia = widget.incidencia;

    return AlertDialog(
      scrollable: true,
      icon: Icon(
        descartar ? Icons.block_outlined : Icons.check_circle_outline,
        color: color,
        size: 44,
      ),
      title: Text(
        descartar ? 'Descartar incidencia' : 'Marcar incidencia como resuelta',
        textAlign: TextAlign.center,
      ),
      content: Form(
        key: formKeyRespuestaGestion,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: controller,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Respuesta de cierre',
                hintText: 'Explica la resolución o el motivo del cierre.',
                alignLabelWithHint: true,
              ),
              validator: _validarRespuestaGestionIncidencia,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 16,
                  color: ColoresUbb.textoSecundario,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Esta respuesta le llegará a ${incidencia.reportadaPorUsuario.nombre} por correo y notificación.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColoresUbb.textoSecundario,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresUbb.rojoInstitucional,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.of(context).pop(null),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Cancelar'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _guardar,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(descartar ? 'Descartar' : 'Marcar resuelta'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormularioIncidencia extends StatelessWidget {
  const _FormularioIncidencia({
    required this.cargando,
    required this.enviando,
    required this.bicicleteros,
    required this.bicicletas,
    required this.bicicleteroSeleccionado,
    required this.bicicletaSeleccionada,
    required this.tipoSeleccionado,
    required this.descripcionController,
    required this.permitirBicicletaPropia,
    required this.onBicicletero,
    required this.onBicicleta,
    required this.onTipo,
    required this.onEnviar,
  });

  final bool cargando;
  final bool enviando;
  final List<BicicleteroApp> bicicleteros;
  final List<BicicletaApp> bicicletas;
  final BicicleteroApp? bicicleteroSeleccionado;
  final BicicletaApp? bicicletaSeleccionada;
  final String tipoSeleccionado;
  final TextEditingController descripcionController;
  final bool permitirBicicletaPropia;
  final ValueChanged<BicicleteroApp?> onBicicletero;
  final ValueChanged<BicicletaApp?> onBicicleta;
  final ValueChanged<String> onTipo;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cargando)
          const Center(child: CircularProgressIndicator())
        else if (bicicleteros.isEmpty)
          const _AvisoFormularioIncidencia(
            icono: Icons.location_off_outlined,
            titulo: 'Sin bicicletero disponible',
            detalle:
                'No hay un bicicletero disponible para asociar el reporte.',
          )
        else ...[
          Container(
            decoration: BoxDecoration(
              color: ColoresUbb.azulApp.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return DropdownAnclado<BicicleteroApp>(
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(16),
                  menuMaxHeight: 300,
                  value: bicicleteroSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Bicicletero',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: Colors.white,
                  items: bicicleteros
                      .map(
                        (bicicletero) => DropdownMenuItem(
                          value: bicicletero,
                          child: Text(
                            bicicletero.nombre,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: enviando ? null : onBicicletero,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (permitirBicicletaPropia)
            Container(
              decoration: BoxDecoration(
                color: ColoresUbb.azulApp.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return DropdownAnclado<BicicletaApp?>(
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(16),
                    menuMaxHeight: 300,
                    value: bicicletaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Bicicleta asociada (opcional)',
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    dropdownColor: Colors.white,
                    items: [
                      const DropdownMenuItem<BicicletaApp?>(
                        value: null,
                        child: Text('Sin bicicleta asociada'),
                      ),
                      ...bicicletas.map(
                        (bicicleta) => DropdownMenuItem<BicicletaApp?>(
                          value: bicicleta,
                          child: Text(
                            bicicleta.descripcion,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                    onChanged: enviando ? null : onBicicleta,
                  );
                },
              ),
            ),
          if (permitirBicicletaPropia) const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: ColoresUbb.azulApp.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return DropdownAnclado<String>(
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(16),
                  menuMaxHeight: 300,
                  value: tipoSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de incidencia',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: Colors.white,
                  items: _tiposIncidencia
                      .map(
                        (tipo) => DropdownMenuItem(
                          value: tipo,
                          child: Text(
                            _etiquetaTipoIncidencia(tipo),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged:
                      enviando ? null : (valor) => onTipo(valor ?? 'OTRO'),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: descripcionController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              hintText: 'Describe el problema con claridad.',
              alignLabelWithHint: true,
            ),
            validator: _validarDescripcionIncidencia,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: enviando ? null : onEnviar,
            icon: enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(enviando ? 'Registrando' : 'Registrar incidencia'),
          ),
        ],
      ],
    );
  }
}

String? _validarDescripcionIncidencia(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa una descripcion.';
  }
  if (texto.length < 8) {
    return 'Debe tener al menos 8 caracteres.';
  }
  if (texto.length > 1000) {
    return 'Maximo 1000 caracteres.';
  }
  return null;
}

String? _validarRespuestaGestionIncidencia(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return 'Ingresa una respuesta de cierre.';
  }
  if (texto.length < 8) {
    return 'Debe explicar el cierre con al menos 8 caracteres.';
  }
  if (texto.length > 1000) {
    return 'Maximo 1000 caracteres.';
  }
  return null;
}

class _AvisoFormularioIncidencia extends StatelessWidget {
  const _AvisoFormularioIncidencia({
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresUbb.azulApp.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresUbb.borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: ColoresUbb.azulApp),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  detalle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColoresUbb.textoSecundario,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltrosIncidencias extends StatelessWidget {
  const _FiltrosIncidencias({
    required this.estado,
    required this.tipo,
    required this.busquedaController,
    required this.onLimpiar,
    required this.onEstado,
    required this.onTipo,
    required this.onBuscar,
    required this.onRegistrar,
  });

  final String estado;
  final String tipo;
  final TextEditingController busquedaController;
  final VoidCallback onLimpiar;
  final ValueChanged<String> onEstado;
  final ValueChanged<String> onTipo;
  final VoidCallback onBuscar;
  final VoidCallback? onRegistrar;

  List<FiltroActivo> _filtrosActivos() {
    final busqueda = busquedaController.text.trim();
    return [
      if (estado != 'TODOS')
        FiltroActivo(
          etiqueta: _etiquetaEstadoIncidencia(estado),
          onQuitar: () => onEstado('TODOS'),
        ),
      if (tipo != 'TODOS')
        FiltroActivo(
          etiqueta: _etiquetaTipoIncidencia(tipo),
          onQuitar: () => onTipo('TODOS'),
        ),
      if (busqueda.isNotEmpty)
        FiltroActivo(
          etiqueta: 'Busca: $busqueda',
          onQuitar: () {
            busquedaController.clear();
            onBuscar();
          },
        ),
    ];
  }

  String _resumenFiltros() {
    final estadoTexto = _etiquetaEstadoIncidencia(estado);
    final tipoTexto =
        tipo == 'TODOS' ? 'Todos los tipos' : _etiquetaTipoIncidencia(tipo);
    return '$estadoTexto | $tipoTexto';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: TituloApartado(titulo: 'Incidencias reportadas'),
            ),
            if (onRegistrar != null) ...[
              const SizedBox(width: 12),
              BotonRegistrarCompacto(
                texto: 'Registrar',
                onPressed: onRegistrar!,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: busquedaController,
          textInputAction: TextInputAction.search,
          onChanged: (_) => onBuscar(),
          onSubmitted: (_) => onBuscar(),
          decoration: InputDecoration(
            labelText: 'Buscar incidencia, bicicletero o descripcion',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: busquedaController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar busqueda',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      busquedaController.clear();
                      onBuscar();
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),
        PanelFiltros(
          titulo: 'Filtros',
          activos: _filtrosActivos(),
          detalle: _resumenFiltros(),
          onLimpiar: onLimpiar,
          children: [
            EtiquetaFiltro(
              texto: 'Estado',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in [
                    'TODOS',
                    'ABIERTAS',
                    'PENDIENTE',
                    'EN_REVISION',
                    'RESUELTA'
                  ])
                    FiltroChip(
                      label: _etiquetaEstadoIncidencia(item),
                      value: item,
                      selectedValue: estado,
                      onTap: onEstado,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            EtiquetaFiltro(
              texto: 'Tipo',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FiltroChip(
                    label: 'Todos los tipos',
                    value: 'TODOS',
                    selectedValue: tipo,
                    onTap: onTipo,
                  ),
                  for (final item in _tiposIncidencia)
                    FiltroChip(
                      label: _etiquetaTipoIncidencia(item),
                      value: item,
                      selectedValue: tipo,
                      onTap: onTipo,
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TarjetaIncidencia extends StatelessWidget {
  const _TarjetaIncidencia({
    required this.incidencia,
    required this.mostrarReportante,
    required this.puedeGestionar,
    required this.gestionGuardia,
    required this.mostrarRecordar,
    required this.onActualizarEstado,
    required this.onRecordar,
    required this.onEsperaCumplida,
  });

  final IncidenciaApp incidencia;
  final bool mostrarReportante;
  final bool puedeGestionar;
  final bool gestionGuardia;
  final bool mostrarRecordar;
  final ValueChanged<String> onActualizarEstado;
  final VoidCallback onRecordar;
  final VoidCallback onEsperaCumplida;

  @override
  Widget build(BuildContext context) {
    final cerrada =
        incidencia.estado == 'RESUELTA' || incidencia.estado == 'DESCARTADA';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.report_problem_outlined,
                    color: ColoresUbb.azulApp),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _etiquetaTipoIncidencia(incidencia.tipo),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                ChipEstado(
                  texto: _etiquetaEstadoIncidencia(incidencia.estado),
                  color: _colorEstadoIncidencia(incidencia.estado),
                ),
              ],
            ),
            const SizedBox(height: 10),
            BloqueMensajeSolicitud(
              titulo: 'Descripción',
              mensaje: incidencia.descripcion,
            ),
            const SizedBox(height: 10),
            FilaDato(
              etiqueta: 'Bicicletero',
              valor: incidencia.bicicletero.nombre,
            ),
            FilaDato(
              etiqueta: 'Fecha',
              valor: formatearFecha(incidencia.creadaEn),
            ),
            FilaDato(
              etiqueta: 'Hora',
              valor: formatearHora(incidencia.creadaEn),
            ),
            if (incidencia.bicicleta != null)
              FilaDato(
                etiqueta: 'Bicicleta',
                valor: incidencia.bicicleta!.descripcion,
              ),
            if (mostrarReportante)
              FilaDato(
                etiqueta: 'Reportada por',
                valor: incidencia.reportadaPorUsuario.nombre,
                anchoCompleto: true,
              ),
            if (incidencia.gestionadaPorUsuario != null)
              FilaDato(
                etiqueta: 'Gestionada por',
                valor: incidencia.gestionadaPorUsuario!.nombre,
                anchoCompleto: true,
              ),
            if (incidencia.respuesta != null &&
                incidencia.respuesta!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              BloqueMensajeSolicitud(
                titulo: 'Respuesta de gestión',
                mensaje: incidencia.respuesta!,
              ),
            ],
            if ((puedeGestionar || mostrarRecordar) && !cerrada) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (puedeGestionar) ...[
                    OutlinedButton.icon(
                      onPressed: incidencia.estado == 'EN_REVISION'
                          ? null
                          : () => onActualizarEstado('EN_REVISION'),
                      icon: const Icon(Icons.manage_search_outlined),
                      label: const Text('En revisión'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => onActualizarEstado('RESUELTA'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Resolver'),
                    ),
                    if (!gestionGuardia)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ColoresUbb.rojoInstitucional,
                          side: const BorderSide(
                            color: ColoresUbb.rojoInstitucional,
                          ),
                        ),
                        onPressed: () => onActualizarEstado('DESCARTADA'),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Descartar'),
                      ),
                  ],
                  if (mostrarRecordar)
                    BotonConEspera(
                      key: ValueKey('recordar-${incidencia.id}'),
                      segundosRestantes: incidencia.segundosParaRecordar,
                      prefijoEspera: 'Podrás recordar en',
                      etiquetaLista: incidencia.recordatorios > 0
                          ? 'Recordar de nuevo'
                          : 'Recordar',
                      icono: Icons.notifications_active_outlined,
                      onPresionar: onRecordar,
                      alTerminarEspera: onEsperaCumplida,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const List<String> _tiposIncidencia = [
  'PROBLEMA_QR',
  'DANO_BICICLETA',
  'DANO_INFRAESTRUCTURA',
  'PROBLEMA_MOVIMIENTO',
  'USUARIO_DATOS',
  'OTRO',
];

String _etiquetaTipoIncidencia(String tipo) {
  return switch (tipo) {
    'PROBLEMA_QR' => 'Problema con QR',
    'DANO_BICICLETA' => 'Daño de bicicleta',
    'DANO_INFRAESTRUCTURA' => 'Daño de infraestructura',
    'PROBLEMA_MOVIMIENTO' => 'Problema de movimiento',
    'USUARIO_DATOS' => 'Datos de usuario',
    'OTRO' => 'Otro',
    _ => tipo,
  };
}

String _etiquetaEstadoIncidencia(String estado) {
  return switch (estado) {
    'TODOS' => 'Todos',
    'ABIERTAS' => 'Abiertas',
    'PENDIENTE' => 'Pendiente',
    'EN_REVISION' => 'En revisión',
    'RESUELTA' => 'Resuelta',
    'DESCARTADA' => 'Descartada',
    _ => estado,
  };
}

Color _colorEstadoIncidencia(String estado) {
  return switch (estado) {
    'PENDIENTE' => ColoresUbb.rojoInstitucional,
    'EN_REVISION' => ColoresUbb.azulApp,
    'RESUELTA' => ColoresUbb.exito,
    'DESCARTADA' => ColoresUbb.textoSecundario,
    _ => ColoresUbb.azulApp,
  };
}
