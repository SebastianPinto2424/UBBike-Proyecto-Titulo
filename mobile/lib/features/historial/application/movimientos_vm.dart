import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/historial/data/historial_repositorio.dart';
import 'package:ubbike/shared/data/bicicleteros_repositorio.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/modelos/historial_modelos.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/utilidades/refresco_coalescido.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';

class FiltrosMovimientosUsuario {
  const FiltrosMovimientosUsuario({
    this.busqueda = '',
    this.periodo = 'MES',
    this.tipo = 'TODOS',
    this.estado = 'TODOS',
    this.origen = 'TODOS',
  });

  final String busqueda;
  final String periodo;
  final String tipo;
  final String estado;
  final String origen;

  FiltrosMovimientosUsuario copyWith({
    String? busqueda,
    String? periodo,
    String? tipo,
    String? estado,
    String? origen,
  }) {
    return FiltrosMovimientosUsuario(
      busqueda: busqueda ?? this.busqueda,
      periodo: periodo ?? this.periodo,
      tipo: tipo ?? this.tipo,
      estado: estado ?? this.estado,
      origen: origen ?? this.origen,
    );
  }
}

final filtrosMovimientosUsuarioProvider =
    StateProvider.autoDispose<FiltrosMovimientosUsuario>(
  (ref) => const FiltrosMovimientosUsuario(),
);

class MovimientosUsuarioVm
    extends AutoDisposeAsyncNotifier<List<MovimientoApp>> {
  Timer? _debounceBusqueda;
  late RefrescoCoalescido _refresco;
  int _revision = 0;
  int _pagina = 1;
  bool hayMas = false;
  bool cargandoMas = false;
  bool desactualizado = false;

  @override
  Future<List<MovimientoApp>> build() {
    final filtros = ref.watch(filtrosMovimientosUsuarioProvider);
    _revision++;
    _pagina = 1;
    hayMas = false;
    cargandoMas = false;
    final refresco = RefrescoCoalescido(
      alRefrescar: _refrescar,
      detectarFallo: () => desactualizado,
    )..iniciarRespaldo();
    _refresco = refresco;
    ref.listen<int>(
        movimientosVersionProvider, (_, __) => refresco.solicitar());
    ref.onDispose(() {
      _revision++;
      refresco.detener();
      _debounceBusqueda?.cancel();
    });
    return _cargar(filtros);
  }

  Future<List<MovimientoApp>> _cargar(FiltrosMovimientosUsuario filtros) async {
    final revision = _revision;
    final paginas = _pagina;
    final datos = <MovimientoApp>[];
    for (var numero = 1; numero <= paginas; numero++) {
      final pagina = await ref.read(historialRepositorioProvider).listarPagina(
          filtro: filtros.busqueda,
          periodo: filtros.periodo,
          tipo: filtros.tipo,
          estado: filtros.estado,
          origen: filtros.origen,
          pagina: numero,
          limite: 20,
          propios: true);
      datos.addAll(pagina.movimientos);
      if (revision != _revision) return datos;
      _pagina = numero;
      hayMas = pagina.hayMas;
      if (!hayMas) break;
    }
    desactualizado = false;
    return {for (final item in datos) item.id: item}.values.toList();
  }

  Future<void> cargarMas() async {
    if (!hayMas || cargandoMas || _refresco.enVuelo) return;
    final revision = _revision;
    final filtros = ref.read(filtrosMovimientosUsuarioProvider);
    cargandoMas = true;
    state = AsyncData([...?state.valueOrNull]);
    try {
      final pagina = await ref.read(historialRepositorioProvider).listarPagina(
          filtro: filtros.busqueda,
          periodo: filtros.periodo,
          tipo: filtros.tipo,
          estado: filtros.estado,
          origen: filtros.origen,
          pagina: _pagina + 1,
          limite: 20,
          propios: true);
      if (revision != _revision) return;
      _pagina = pagina.pagina;
      hayMas = pagina.hayMas;
      state = AsyncData({
        for (final item in [...?state.valueOrNull, ...pagina.movimientos])
          item.id: item
      }.values.toList());
    } catch (_) {
      if (revision == _revision) desactualizado = true;
    } finally {
      if (revision == _revision) {
        cargandoMas = false;
        state = AsyncData([...?state.valueOrNull]);
      }
    }
  }

  Future<void> refrescar() => _refresco.solicitar();

  Future<void> _refrescar() async {
    if (cargandoMas) return;
    final revision = _revision;
    try {
      final datos = await _cargar(ref.read(filtrosMovimientosUsuarioProvider));
      if (revision == _revision) state = AsyncData(datos);
    } catch (error, stackTrace) {
      if (revision == _revision) {
        desactualizado = true;
        state = state.hasValue
            ? AsyncData([...state.valueOrNull!])
            : AsyncError(error, stackTrace);
      }
    }
  }

  void recargar() {
    ref.invalidateSelf();
  }

  void buscar(String valor) {
    _debounceBusqueda?.cancel();
    _debounceBusqueda = Timer(const Duration(milliseconds: 350), () {
      final filtros = ref.read(filtrosMovimientosUsuarioProvider);
      ref.read(filtrosMovimientosUsuarioProvider.notifier).state =
          filtros.copyWith(busqueda: valor.trim());
    });
  }

  void cambiarFiltros({
    String? periodo,
    String? tipo,
    String? estado,
    String? origen,
  }) {
    final filtros = ref.read(filtrosMovimientosUsuarioProvider);
    ref.read(filtrosMovimientosUsuarioProvider.notifier).state =
        filtros.copyWith(
      periodo: periodo,
      tipo: tipo,
      estado: estado,
      origen: origen,
    );
  }

  void limpiarFiltros() {
    _debounceBusqueda?.cancel();
    ref.read(filtrosMovimientosUsuarioProvider.notifier).state =
        const FiltrosMovimientosUsuario();
  }
}

final movimientosUsuarioVmProvider = AsyncNotifierProvider.autoDispose<
    MovimientosUsuarioVm, List<MovimientoApp>>(MovimientosUsuarioVm.new);

class MovimientosCentralVm {
  const MovimientosCentralVm(this._ref);

  final Ref _ref;

  Future<List<MovimientoApp>> listar({
    String? filtro,
    String? periodo,
    DateTime? desde,
    DateTime? hasta,
    String? tipo,
    String? estado,
    String? bicicleteroId,
    String? guardiaId,
    String? origen,
    int? limite,
  }) =>
      _ref.read(historialRepositorioProvider).listar(
            filtro: filtro,
            periodo: periodo,
            desde: desde,
            hasta: hasta,
            tipo: tipo,
            estado: estado,
            bicicleteroId: bicicleteroId,
            guardiaId: guardiaId,
            origen: origen,
            limite: limite,
          );

  Future<PaginaMovimientosApp> listarPagina({
    String? filtro,
    String? periodo,
    DateTime? desde,
    DateTime? hasta,
    String? tipo,
    String? estado,
    String? bicicleteroId,
    String? guardiaId,
    String? origen,
    int? limite,
    int pagina = 1,
  }) =>
      _ref.read(historialRepositorioProvider).listarPagina(
            filtro: filtro,
            periodo: periodo,
            desde: desde,
            hasta: hasta,
            tipo: tipo,
            estado: estado,
            bicicleteroId: bicicleteroId,
            guardiaId: guardiaId,
            origen: origen,
            limite: limite,
            pagina: pagina,
          );

  Future<OpcionesHistorialApp> opciones() =>
      _ref.read(historialRepositorioProvider).opciones();

  Future<List<BicicleteroApp>> listarBicicleteros() =>
      _ref.read(bicicleterosRepositorioProvider).listar();

  Future<Uint8List> exportarExcel({
    String? filtro,
    String? periodo,
    DateTime? desde,
    DateTime? hasta,
    String? tipo,
    String? estado,
    String? bicicleteroId,
    String? guardiaId,
    String? origen,
  }) =>
      _ref.read(historialRepositorioProvider).exportarExcel(
            filtro: filtro,
            periodo: periodo,
            desde: desde,
            hasta: hasta,
            tipo: tipo,
            estado: estado,
            bicicleteroId: bicicleteroId,
            guardiaId: guardiaId,
            origen: origen,
          );
}

final movimientosCentralVmProvider = Provider.autoDispose<MovimientosCentralVm>(
  (ref) => MovimientosCentralVm(ref),
);
