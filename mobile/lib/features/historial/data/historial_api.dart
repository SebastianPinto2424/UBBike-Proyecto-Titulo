import 'dart:typed_data';

import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/modelos/historial_modelos.dart';

class HistorialApi {
  const HistorialApi({required this.cliente});

  final ClienteApi cliente;

  String _crearQuery({
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
    int? pagina,
  }) {
    final parametros = <String>[];

    void agregar(String llave, String? valor) {
      if (valor != null && valor.trim().isNotEmpty && valor != 'TODOS') {
        parametros.add('$llave=${Uri.encodeQueryComponent(valor.trim())}');
      }
    }

    String fecha(DateTime valor) {
      final local = DateTime(valor.year, valor.month, valor.day);
      final mes = local.month.toString().padLeft(2, '0');
      final dia = local.day.toString().padLeft(2, '0');
      return '${local.year}-$mes-$dia';
    }

    agregar('q', filtro);
    agregar('periodo', desde == null && hasta == null ? periodo : null);
    agregar('desde', desde == null ? null : fecha(desde));
    agregar('hasta', hasta == null ? null : fecha(hasta));
    agregar('tipo', tipo);
    agregar('estado', estado);
    agregar('bicicleteroId', bicicleteroId);
    agregar('guardiaId', guardiaId);
    agregar('origen', origen);
    if (limite != null && limite > 0) {
      parametros.add('limit=$limite');
    }
    if (pagina != null && pagina > 1) {
      parametros.add('page=$pagina');
    }

    return parametros.isEmpty ? '' : '?${parametros.join('&')}';
  }

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
  }) async {
    final query = _crearQuery(
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
    final respuesta = await cliente.get('/historial$query');
    final datos =
        (respuesta['movimientos'] ?? respuesta['datos']) as List<dynamic>;
    return datos
        .map((item) => MovimientoApp.desdeJson(item as Map<String, dynamic>))
        .toList();
  }

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
  }) async {
    final query = _crearQuery(
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

    return PaginaMovimientosApp.desdeJson(
        await cliente.get('/historial$query'));
  }

  Future<ResumenHistorialApp> resumen({
    String? periodo,
    DateTime? desde,
    DateTime? hasta,
    String? tipo,
    String? estado,
    String? bicicleteroId,
    String? guardiaId,
    String? origen,
  }) async {
    final query = _crearQuery(
      periodo: periodo,
      desde: desde,
      hasta: hasta,
      tipo: tipo,
      estado: estado,
      bicicleteroId: bicicleteroId,
      guardiaId: guardiaId,
      origen: origen,
    );
    final respuesta = await cliente.get('/historial/resumen$query');
    return ResumenHistorialApp.desdeJson(
      respuesta['resumen'] as Map<String, dynamic>,
    );
  }

  Future<OpcionesHistorialApp> opciones() async {
    final respuesta = await cliente.get('/historial/opciones');
    return OpcionesHistorialApp.desdeJson(respuesta);
  }

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
  }) {
    final query = _crearQuery(
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
    return cliente.getBytes('/historial/exportar-excel$query');
  }
}
