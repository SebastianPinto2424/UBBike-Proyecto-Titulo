import 'dart:typed_data';

import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/features/historial/data/historial_api.dart';
import 'package:ubbike/shared/modelos/historial_modelos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/providers/cliente_api_provider.dart';

class HistorialRepositorio {
  const HistorialRepositorio(this._api);

  final HistorialApi _api;

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
      _api.listar(
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
      _api.listarPagina(
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

  Future<ResumenHistorialApp> resumen({
    String? periodo,
    DateTime? desde,
    DateTime? hasta,
    String? tipo,
    String? estado,
    String? bicicleteroId,
    String? guardiaId,
    String? origen,
  }) =>
      _api.resumen(
        periodo: periodo,
        desde: desde,
        hasta: hasta,
        tipo: tipo,
        estado: estado,
        bicicleteroId: bicicleteroId,
        guardiaId: guardiaId,
        origen: origen,
      );

  Future<OpcionesHistorialApp> opciones() => _api.opciones();

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
      _api.exportarExcel(
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

final historialRepositorioProvider = Provider<HistorialRepositorio>((ref) {
  final cliente = ref.watch(clienteApiProvider);
  return HistorialRepositorio(HistorialApi(cliente: cliente));
});
