import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/core/servicios/excepcion_api.dart';
import 'package:ubbike/core/tema/colores_ubb.dart';
import 'package:ubbike/features/acceso/application/guardias_en_turno_vm.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:ubbike/features/acceso/presentation/lista_guardias_en_turno.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/utilidades/auto_refresco.dart';
import 'package:ubbike/shared/widgets/dialogo_eliminar.dart';
import 'package:ubbike/shared/widgets/estado_widgets.dart';
import 'package:ubbike/shared/widgets/selector_desplegable.dart';
import 'package:ubbike/shared/widgets/snackbar_semantico.dart';

enum _Desplegable { bicicletero, guardia }

class VistaGuardiasEnTurno extends ConsumerStatefulWidget {
  const VistaGuardiasEnTurno({super.key});

  @override
  ConsumerState<VistaGuardiasEnTurno> createState() =>
      _VistaGuardiasEnTurnoState();
}

class _VistaGuardiasEnTurnoState extends ConsumerState<VistaGuardiasEnTurno>
    with AutoRefrescoMixin {
  GuardiasEnTurnoVm get vm => ref.read(guardiasEnTurnoVmProvider);
  List<BicicleteroApp> bicicleteros = [];
  List<GuardiaTurnoApp> guardias = [];
  String? bicicleteroElegidoId;
  String? guardiaElegidoId;
  _Desplegable? desplegado;
  bool cargando = true;
  bool fallo = false;
  bool asignando = false;
  String? liberando;
  bool ultimaRecargaFallida = false;

  List<BicicleteroApp> get _disponibles =>
      bicicleteros.where((item) => !item.tieneGuardia).toList();

  BicicleteroApp? get _bicicleteroElegido {
    for (final item in _disponibles) {
      if (item.id == bicicleteroElegidoId) {
        return item;
      }
    }
    return null;
  }

  GuardiaTurnoApp? get _guardiaElegido {
    for (final guardia in guardias) {
      if (guardia.id == guardiaElegidoId) {
        return guardia;
      }
    }
    return null;
  }

  @override
  bool get datosDesactualizados => ultimaRecargaFallida;

  @override
  void initState() {
    super.initState();
    _cargar();
    iniciarAutoRefresco();
  }

  @override
  Future<void> refrescar() async {
    if (asignando || liberando != null) {
      return;
    }
    await _cargar(silencioso: true);
  }

  Future<void> _cargar({bool silencioso = false}) async {
    try {
      final resultados = await Future.wait([
        vm.listarBicicleteros(),
        vm.listarGuardias(),
      ]);
      if (!mounted) {
        return;
      }
      final elegido = bicicleteroElegidoId;
      setState(() {
        bicicleteros = resultados[0] as List<BicicleteroApp>;
        guardias = resultados[1] as List<GuardiaTurnoApp>;
        cargando = false;
        fallo = false;
        ultimaRecargaFallida = false;
        if (_bicicleteroElegido == null) {
          bicicleteroElegidoId = null;
        }
        if (_guardiaElegido == null) {
          guardiaElegidoId = null;
        }
      });
      if (elegido != null && bicicleteroElegidoId == null) {
        _avisarBicicleteroTomado(elegido);
      }
    } catch (_) {
      ultimaRecargaFallida = true;
      if (!mounted || silencioso) {
        return;
      }
      setState(() {
        cargando = false;
        fallo = true;
      });
    }
  }

  void _avisarBicicleteroTomado(String bicicleteroId) {
    final tomado = bicicleteros.where((item) => item.id == bicicleteroId);
    context.mostrarInfo(
      tomado.isEmpty
          ? 'El bicicletero elegido ya no está disponible.'
          : '${tomado.first.nombre} ya tiene guardia. Elige otro bicicletero.',
    );
  }

  void _reintentar() {
    setState(() {
      cargando = true;
      fallo = false;
    });
    _cargar();
  }

  void _alternar(_Desplegable cual) {
    setState(() => desplegado = desplegado == cual ? null : cual);
  }

  Future<void> _ejecutar(Future<String> Function() accion) async {
    try {
      final mensaje = await accion();
      if (mounted) {
        context.mostrarExito(mensaje);
      }
    } on ExcepcionApi catch (error) {
      if (mounted) {
        context.mostrarError(error.mensaje);
      }
    } catch (_) {
      if (mounted) {
        context.mostrarError(mensajeSinConexion);
      }
    }
  }

  Future<void> _asignar() async {
    final bicicletero = _bicicleteroElegido;
    final guardia = _guardiaElegido;
    if (bicicletero == null || guardia == null || asignando) {
      return;
    }

    if (guardia.enTurno) {
      final confirmar = await confirmarEliminacion(
        context,
        titulo: 'Trasladar guardia',
        nombre: guardia.nombre,
        consecuencia:
            'Dejará ${guardia.bicicleteroNombre} y pasará a ${bicicletero.nombre}. Sus solicitudes sin responder en ${guardia.bicicleteroNombre} quedarán pendientes.',
        etiquetaConfirmar: 'Trasladar',
        icono: Icons.swap_horiz,
      );
      if (!confirmar || !mounted) {
        return;
      }
    }

    setState(() {
      asignando = true;
      desplegado = null;
    });
    await _ejecutar(() async {
      await vm.asignar(bicicletero.id, guardia.id);
      if (mounted) {
        setState(() {
          bicicleteroElegidoId = null;
          guardiaElegidoId = null;
        });
      }
      return '${guardia.nombre} ahora gestiona ${bicicletero.nombre}';
    });
    if (!mounted) {
      return;
    }
    setState(() => asignando = false);
    await _cargar(silencioso: true);
  }

  Future<void> _liberar(BicicleteroApp bicicletero) async {
    final confirmar = await confirmarEliminacion(
      context,
      titulo: 'Liberar bicicletero',
      nombre: bicicletero.nombre,
      consecuencia:
          '${bicicletero.guardiaActivoNombre} dejará de gestionarlo. Sus solicitudes sin responder quedarán pendientes para el próximo guardia.',
      etiquetaConfirmar: 'Liberar',
      icono: Icons.logout,
    );
    if (!confirmar || !mounted) {
      return;
    }

    setState(() => liberando = bicicletero.id);
    await _ejecutar(() => vm.liberar(bicicletero.id));
    if (!mounted) {
      return;
    }
    setState(() => liberando = null);
    await _cargar(silencioso: true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
        bicicleterosVersionProvider, (_, __) => solicitarRefresco());
    ref.listen<int>(usuariosVersionProvider, (_, __) => solicitarRefresco());

    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (fallo) {
      return ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 16),
        children: [
          const EstadoLista(
            icono: Icons.cloud_off_outlined,
            titulo: 'No se pudo cargar la información',
            detalle: 'Revisa tu conexión e intenta nuevamente.',
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _reintentar,
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    if (bicicleteros.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 16),
        children: const [
          EstadoLista(
            icono: Icons.location_off_outlined,
            titulo: 'Sin bicicleteros activos',
            detalle: 'Habilita bicicleteros desde configuración.',
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 16),
        children: [
          _formularioAsignacion(context),
          const SizedBox(height: 24),
          ListaGuardiasEnTurno(
            bicicleteros: bicicleteros,
            liberandoId: liberando,
            habilitado: liberando == null && !asignando,
            onLiberar: _liberar,
          ),
        ],
      ),
    );
  }

  Widget _formularioAsignacion(BuildContext context) {
    final disponibles = _disponibles;
    final bicicletero = _bicicleteroElegido;
    final guardia = _guardiaElegido;
    final ordenados = [...guardias]..sort(_libresPrimero);
    final ocupado = asignando || liberando != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloApartado(titulo: 'Asignar guardia'),
        const SizedBox(height: 2),
        Text(
          'Elige un bicicletero sin guardia y quién lo gestionará.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ColoresUbb.textoSecundario,
              ),
        ),
        const SizedBox(height: 12),
        CampoDesplegable(
          etiqueta: 'Bicicletero sin guardia',
          texto: bicicletero?.nombre ??
              (disponibles.isEmpty
                  ? 'Todos los bicicleteros tienen guardia'
                  : 'Selecciona un bicicletero'),
          vacio: bicicletero == null,
          maxLineas: 2,
          abierto: desplegado == _Desplegable.bicicletero,
          onTap: disponibles.isEmpty || ocupado
              ? null
              : () => _alternar(_Desplegable.bicicletero),
        ),
        PanelOpcionesDesplegable(
          abierto: desplegado == _Desplegable.bicicletero,
          opciones: [
            for (final item in disponibles)
              OpcionDesplegable(
                titulo: item.nombre,
                detalle: item.cuposDisponibles == 1
                    ? '1 cupo disponible'
                    : '${item.cuposDisponibles} cupos disponibles',
                seleccionada: item.id == bicicleteroElegidoId,
                onTap: () => setState(() {
                  bicicleteroElegidoId = item.id;
                  desplegado = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        CampoDesplegable(
          etiqueta: 'Guardia',
          icono: Icons.badge_outlined,
          texto: guardia == null
              ? (guardias.isEmpty
                  ? 'No hay guardias habilitados'
                  : 'Selecciona un guardia')
              : '${guardia.nombre} · ${_detalleGuardia(guardia)}',
          vacio: guardia == null,
          maxLineas: 2,
          abierto: desplegado == _Desplegable.guardia,
          onTap: guardias.isEmpty || ocupado
              ? null
              : () => _alternar(_Desplegable.guardia),
        ),
        PanelOpcionesDesplegable(
          abierto: desplegado == _Desplegable.guardia,
          opciones: [
            for (final item in ordenados)
              OpcionDesplegable(
                titulo: item.nombre,
                detalle: _detalleGuardia(item),
                seleccionada: item.id == guardiaElegidoId,
                onTap: () => setState(() {
                  guardiaElegidoId = item.id;
                  desplegado = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: ColoresUbb.azulApp,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: bicicletero == null || guardia == null || ocupado
              ? null
              : _asignar,
          icon: asignando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.how_to_reg_outlined),
          label: Text(
            asignando ? 'Asignando...' : 'Asignar guardia',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

String _detalleGuardia(GuardiaTurnoApp guardia) =>
    guardia.enTurno ? 'En ${guardia.bicicleteroNombre}' : 'Sin bicicletero';

int _libresPrimero(GuardiaTurnoApp a, GuardiaTurnoApp b) {
  if (a.enTurno != b.enTurno) {
    return a.enTurno ? 1 : -1;
  }
  return a.nombre.compareTo(b.nombre);
}
