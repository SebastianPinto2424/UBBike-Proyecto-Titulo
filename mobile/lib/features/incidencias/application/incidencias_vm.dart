import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/repositorios_provider.dart';
import 'package:ubbike/features/incidencias/data/incidencia_modelos.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/utils/refresco_coalescido.dart';

class FiltrosIncidencias {
  const FiltrosIncidencias({
    this.estado = 'TODOS',
    this.tipo = 'TODOS',
    this.busqueda = '',
  });

  final String estado;
  final String tipo;
  final String busqueda;

  FiltrosIncidencias copyWith(
      {String? estado, String? tipo, String? busqueda}) {
    return FiltrosIncidencias(
      estado: estado ?? this.estado,
      tipo: tipo ?? this.tipo,
      busqueda: busqueda ?? this.busqueda,
    );
  }
}

final filtrosIncidenciasProvider =
    StateProvider.autoDispose<FiltrosIncidencias>(
  (ref) => const FiltrosIncidencias(),
);

final incidenciasVersionProvider = StateProvider<int>((ref) => 0);

class IncidenciasVm extends AutoDisposeAsyncNotifier<List<IncidenciaApp>> {
  Timer? _debounceBusqueda;
  late RefrescoCoalescido _refresco;
  int _revision = 0;
  String? _cursor;
  bool cargandoMas = false;
  bool desactualizado = false;
  bool get hayMas => _cursor != null;

  @override
  Future<List<IncidenciaApp>> build() {
    final filtros = ref.watch(filtrosIncidenciasProvider);
    _revision++;
    _cursor = null;
    cargandoMas = false;
    final refresco = RefrescoCoalescido(
      alRefrescar: _refrescar,
      detectarFallo: () => desactualizado,
    )..iniciarRespaldo();
    _refresco = refresco;
    ref.listen<int>(
        incidenciasVersionProvider, (_, __) => refresco.solicitar());
    ref.onDispose(() {
      _revision++;
      refresco.detener();
      _debounceBusqueda?.cancel();
    });
    return _cargar(filtros);
  }

  Future<List<IncidenciaApp>> _cargar(FiltrosIncidencias filtros,
      {int conservar = 0}) async {
    final revision = _revision;
    var pagina = await ref.read(incidenciaRepositoryProvider).listarPagina(
          estado: filtros.estado,
          tipo: filtros.tipo,
          q: filtros.busqueda,
        );
    final datos = [...pagina.datos];
    while (datos.length < conservar &&
        pagina.cursor != null &&
        revision == _revision) {
      pagina = await ref.read(incidenciaRepositoryProvider).listarPagina(
          estado: filtros.estado,
          tipo: filtros.tipo,
          q: filtros.busqueda,
          cursor: pagina.cursor);
      datos.addAll(pagina.datos);
    }
    if (revision == _revision) {
      _cursor = pagina.cursor;
      desactualizado = false;
    }
    return {for (final item in datos) item.id: item}.values.toList();
  }

  Future<void> refrescar() => _refresco.solicitar();

  Future<void> _refrescar() async {
    if (cargandoMas) return;
    final revision = _revision;
    try {
      final datos = await _cargar(ref.read(filtrosIncidenciasProvider),
          conservar: state.valueOrNull?.length ?? 0);
      if (revision == _revision) state = AsyncData(datos);
    } catch (error, stackTrace) {
      if (revision != _revision) return;
      desactualizado = true;
      if (!state.hasValue) {
        state = AsyncError(error, stackTrace);
      } else {
        state = AsyncData([...state.valueOrNull!]);
      }
    }
  }

  Future<void> cargarMas() async {
    final cursor = _cursor;
    if (cursor == null || cargandoMas || _refresco.enVuelo) return;
    final revision = _revision;
    final filtros = ref.read(filtrosIncidenciasProvider);
    cargandoMas = true;
    state = AsyncData([...?state.valueOrNull]);
    try {
      final pagina = await ref.read(incidenciaRepositoryProvider).listarPagina(
            estado: filtros.estado,
            tipo: filtros.tipo,
            q: filtros.busqueda,
            cursor: cursor,
          );
      if (revision != _revision) return;
      _cursor = pagina.cursor;
      final porId = {
        for (final item in [...?state.valueOrNull, ...pagina.datos])
          item.id: item
      };
      state = AsyncData(porId.values.toList());
    } catch (_) {
      if (revision == _revision) desactualizado = true;
    } finally {
      if (revision == _revision) {
        cargandoMas = false;
        state = AsyncData([...?state.valueOrNull]);
      }
    }
  }

  void recargar() {
    ref.invalidateSelf();
  }

  void buscar(String valor) {
    _debounceBusqueda?.cancel();
    _debounceBusqueda = Timer(const Duration(milliseconds: 350), () {
      final filtros = ref.read(filtrosIncidenciasProvider);
      ref.read(filtrosIncidenciasProvider.notifier).state =
          filtros.copyWith(busqueda: valor.trim());
    });
  }

  void cambiarEstado(String valor) {
    final filtros = ref.read(filtrosIncidenciasProvider);
    ref.read(filtrosIncidenciasProvider.notifier).state =
        filtros.copyWith(estado: valor);
  }

  void cambiarTipo(String valor) {
    final filtros = ref.read(filtrosIncidenciasProvider);
    ref.read(filtrosIncidenciasProvider.notifier).state =
        filtros.copyWith(tipo: valor);
  }

  void limpiarFiltros() {
    _debounceBusqueda?.cancel();
    ref.read(filtrosIncidenciasProvider.notifier).state =
        const FiltrosIncidencias();
  }

  Future<void> crear({
    required String bicicleteroId,
    required String tipo,
    required String descripcion,
    String? bicicletaId,
  }) async {
    await ref.read(incidenciaRepositoryProvider).crear(
          bicicleteroId: bicicleteroId,
          tipo: tipo,
          descripcion: descripcion,
          bicicletaId: bicicletaId,
        );
    recargar();
  }

  Future<void> actualizarEstado({
    required String incidenciaId,
    required String estado,
    String? respuesta,
  }) async {
    await ref.read(incidenciaRepositoryProvider).actualizarEstado(
          incidenciaId: incidenciaId,
          estado: estado,
          respuesta: respuesta,
        );
    recargar();
  }

  Future<void> recordar({required String incidenciaId}) async {
    await ref
        .read(incidenciaRepositoryProvider)
        .recordar(incidenciaId: incidenciaId);
    recargar();
  }
}

final incidenciasVmProvider =
    AsyncNotifierProvider.autoDispose<IncidenciasVm, List<IncidenciaApp>>(
  IncidenciasVm.new,
);

class DatosFormularioIncidencia {
  const DatosFormularioIncidencia({
    required this.bicicleteros,
    required this.bicicletas,
  });

  final List<BicicleteroApp> bicicleteros;
  final List<BicicletaApp> bicicletas;
}

final datosFormularioIncidenciaProvider = FutureProvider.autoDispose.family<
    DatosFormularioIncidencia,
    ({bool gestionGuardia, bool permitirBicicletaPropia})>(
  (ref, args) async {
    final solicitudGuardiaRepository =
        ref.read(solicitudGuardiaRepositoryProvider);
    final datosBicicletero = args.gestionGuardia
        ? await solicitudGuardiaRepository.obtenerBicicleteroGestionado()
        : null;
    final bicicleteros = args.gestionGuardia
        ? [if (datosBicicletero != null) datosBicicletero]
        : await solicitudGuardiaRepository.listarBicicleteros();
    final bicicletas = args.permitirBicicletaPropia
        ? await ref.read(bicicletaRepositoryProvider).listar()
        : <BicicletaApp>[];

    return DatosFormularioIncidencia(
      bicicleteros: bicicleteros,
      bicicletas: bicicletas,
    );
  },
);
