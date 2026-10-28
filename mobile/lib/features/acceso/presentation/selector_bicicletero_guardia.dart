import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/features/acceso/application/solicitudes_guardia_vm.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/utilidades/auto_refresco.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/selector_desplegable.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';

class SelectorBicicleteroGuardiaPerfil extends ConsumerStatefulWidget {
  const SelectorBicicleteroGuardiaPerfil({super.key, this.onCambiado});

  final VoidCallback? onCambiado;

  @override
  ConsumerState<SelectorBicicleteroGuardiaPerfil> createState() =>
      _SelectorBicicleteroGuardiaPerfilState();
}

class _SelectorBicicleteroGuardiaPerfilState
    extends ConsumerState<SelectorBicicleteroGuardiaPerfil>
    with AutoRefrescoMixin {
  SolicitudesGuardiaVm get vm => ref.read(solicitudesGuardiaVmProvider);
  List<BicicleteroApp> bicicleteros = [];
  BicicleteroApp? bicicleteroSeleccionado;
  bool cargando = true;
  bool guardando = false;
  bool liberando = false;
  bool abierto = false;
  bool ultimaRecargaFallida = false;

  String? get _miId {
    final sesion = ref.read(sesionProvider).valueOrNull;
    return sesion is SesionActiva ? sesion.usuario.id : null;
  }

  void _terminarOperacion() {
    if (mounted) _cargar(silencioso: true);
  }

  @override
  void initState() {
    super.initState();
    _cargar();
    iniciarAutoRefresco();
  }

  @override
  bool get datosDesactualizados => ultimaRecargaFallida;

  @override
  Future<void> refrescar() async {
    if (!guardando && !liberando) await _cargar(silencioso: true);
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => cargando = true);

    try {
      final resultados = await Future.wait([
        vm.listarBicicleteros(),
        vm.obtenerBicicleteroGestionado(),
      ]);
      final lista = resultados[0] as List<BicicleteroApp>;
      final actual = resultados[1] as BicicleteroApp?;
      final seleccionado = actual == null
          ? null
          : lista.cast<BicicleteroApp?>().firstWhere(
                (item) => item?.id == actual.id,
                orElse: () => null,
              );

      if (!mounted) {
        return;
      }

      setState(() {
        bicicleteros = lista;
        bicicleteroSeleccionado = seleccionado;
        cargando = false;
        ultimaRecargaFallida = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        cargando = false;
        ultimaRecargaFallida = true;
      });
      if (!silencioso) {
        context.mostrarError(
            error is ExcepcionApi ? error.mensaje : mensajeSinConexion);
      }
    }
  }

  Future<void> _guardar() async {
    final seleccionado = bicicleteroSeleccionado;
    if (seleccionado == null || guardando) {
      return;
    }

    setState(() => guardando = true);

    try {
      final actualizado =
          await vm.seleccionarBicicleteroGestionado(seleccionado.id);

      if (!mounted) {
        return;
      }

      setState(() {
        bicicleteros = bicicleteros
            .map((item) => item.id == actualizado.id ? actualizado : item)
            .toList();
        bicicleteroSeleccionado = bicicleteros.firstWhere(
          (item) => item.id == actualizado.id,
        );
        guardando = false;
        abierto = false;
      });
      context.mostrarExito('Ahora gestionas ${actualizado.nombre}');
      widget.onCambiado?.call();
    } on ExcepcionApi catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => guardando = false);
      context.mostrarError(error.mensaje);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => guardando = false);
      context.mostrarError(mensajeSinConexion);
    }
    _terminarOperacion();
  }

  Future<void> _liberar() async {
    if (guardando || bicicleteroSeleccionado == null) {
      return;
    }

    setState(() {
      guardando = true;
      liberando = true;
    });

    try {
      await vm.liberarBicicleteroGestionado();

      if (!mounted) {
        return;
      }

      setState(() {
        bicicleteroSeleccionado = null;
        guardando = false;
        liberando = false;
        abierto = false;
      });
      context.mostrarExito('Ya no gestionas un bicicletero');
      widget.onCambiado?.call();
    } on ExcepcionApi catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        guardando = false;
        liberando = false;
      });
      context.mostrarError(error.mensaje);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        guardando = false;
        liberando = false;
      });
      context.mostrarError(mensajeSinConexion);
    }
    _terminarOperacion();
  }

  String _textoBicicleteroSeleccionado() {
    final seleccionado = bicicleteroSeleccionado;
    if (seleccionado == null) {
      return 'Selecciona un bicicletero';
    }

    final cupos = seleccionado.cuposDisponibles == 1
        ? '1 cupo libre'
        : '${seleccionado.cuposDisponibles} cupos libres';
    return '${seleccionado.nombre} · $cupos';
  }

  Widget _opcionNinguno() {
    final seleccionado = bicicleteroSeleccionado == null;
    return OpcionDesplegable(
      titulo: 'Ninguno',
      detalle: 'Dejar de gestionar un bicicletero',
      seleccionada: seleccionado,
      cargando: liberando,
      onTap: guardando || seleccionado ? null : _liberar,
    );
  }

  Widget _opcionBicicletero(BicicleteroApp bicicletero) {
    final seleccionado = bicicleteroSeleccionado?.id == bicicletero.id;
    final deOtroGuardia = bicicletero.tieneGuardia &&
        bicicletero.guardiaActivoId != _miId &&
        !seleccionado;
    return OpcionDesplegable(
      titulo: bicicletero.nombre,
      detalle: deOtroGuardia
          ? 'Lo gestiona ${bicicletero.guardiaActivoNombre}'
          : '${bicicletero.cuposDisponibles} cupos disponibles',
      seleccionada: seleccionado,
      bloqueada: deOtroGuardia,
      cargando: guardando && seleccionado,
      onTap: guardando || seleccionado || deOtroGuardia
          ? null
          : () {
              setState(() => bicicleteroSeleccionado = bicicletero);
              _guardar();
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
        bicicleterosVersionProvider, (_, __) => solicitarRefresco());

    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bicicleteros.isEmpty) {
      return const EstadoLista(
        icono: Icons.location_off_outlined,
        titulo: 'Sin bicicleteros activos',
        detalle: 'Central debe habilitar al menos un bicicletero.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampoDesplegable(
          etiqueta: 'Bicicletero a gestionar',
          texto: _textoBicicleteroSeleccionado(),
          vacio: bicicleteroSeleccionado == null,
          abierto: abierto,
          onTap: () => setState(() => abierto = !abierto),
        ),
        PanelOpcionesDesplegable(
          abierto: abierto,
          opciones: [
            _opcionNinguno(),
            ...bicicleteros.map(_opcionBicicletero),
          ],
        ),
      ],
    );
  }
}
