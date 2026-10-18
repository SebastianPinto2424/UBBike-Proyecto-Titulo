import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';

class PaginaMovimientosApp {
  const PaginaMovimientosApp({
    required this.movimientos,
    required this.pagina,
    required this.totalPaginas,
    required this.total,
  });

  final List<MovimientoApp> movimientos;
  final int pagina;
  final int totalPaginas;
  final int total;

  bool get hayMas => pagina < totalPaginas;

  factory PaginaMovimientosApp.desdeJson(Map<String, dynamic> json) {
    final datos = (json['movimientos'] ?? json['datos']) as List<dynamic>;
    final metadatos = json['metadatos'] as Map<String, dynamic>?;

    return PaginaMovimientosApp(
      movimientos: datos
          .map((item) => MovimientoApp.desdeJson(item as Map<String, dynamic>))
          .toList(),
      pagina: metadatos?['pagina'] as int? ?? 1,
      totalPaginas: metadatos?['totalPaginas'] as int? ?? 1,
      total: metadatos?['total'] as int? ?? datos.length,
    );
  }
}

class ResumenHistorialApp {
  const ResumenHistorialApp({
    required this.totalMovimientos,
    required this.ingresos,
    required this.retiros,
    required this.confirmados,
    required this.denegados,
    required this.manuales,
    required this.qr,
    required this.operacionesPorGuardia,
    required this.operacionesPorBicicletero,
    this.incidenciasAbiertas = 0,
    this.solicitudesAbiertas = 0,
    this.usuariosActivos = 0,
    this.usuariosInactivos = 0,
    this.usuariosSinVerificar = 0,
  });

  final int totalMovimientos;
  final int incidenciasAbiertas;
  final int solicitudesAbiertas;
  final int usuariosActivos;
  final int usuariosInactivos;
  final int usuariosSinVerificar;
  final int ingresos;
  final int retiros;
  final int confirmados;
  final int denegados;
  final int manuales;
  final int qr;
  final Map<String, int> operacionesPorGuardia;
  final Map<String, int> operacionesPorBicicletero;

  factory ResumenHistorialApp.desdeJson(Map<String, dynamic> json) {
    Map<String, int> mapa(String llave) {
      final datos = json[llave] as Map<String, dynamic>? ?? const {};
      return datos.map((clave, valor) => MapEntry(clave, valor as int));
    }

    return ResumenHistorialApp(
      totalMovimientos: json['totalMovimientos'] as int? ?? 0,
      ingresos: json['ingresos'] as int? ?? 0,
      retiros: json['retiros'] as int? ?? 0,
      confirmados: json['confirmados'] as int? ?? 0,
      denegados: json['denegados'] as int? ?? 0,
      manuales: json['manuales'] as int? ?? 0,
      qr: json['qr'] as int? ?? 0,
      operacionesPorGuardia: mapa('operacionesPorGuardia'),
      operacionesPorBicicletero: mapa('operacionesPorBicicletero'),
      incidenciasAbiertas: json['incidenciasAbiertas'] as int? ?? 0,
      solicitudesAbiertas: json['solicitudesAbiertas'] as int? ?? 0,
      usuariosActivos: json['usuariosActivos'] as int? ?? 0,
      usuariosInactivos: json['usuariosInactivos'] as int? ?? 0,
      usuariosSinVerificar: json['usuariosSinVerificar'] as int? ?? 0,
    );
  }
}

class OpcionesHistorialApp {
  const OpcionesHistorialApp({
    required this.bicicleteros,
    required this.guardias,
  });

  final List<BicicleteroApp> bicicleteros;
  final List<UsuarioApp> guardias;

  factory OpcionesHistorialApp.desdeJson(Map<String, dynamic> json) {
    return OpcionesHistorialApp(
      bicicleteros: (json['bicicleteros'] as List<dynamic>? ?? const [])
          .map((item) => BicicleteroApp.desdeJson(item as Map<String, dynamic>))
          .toList(),
      guardias: (json['guardias'] as List<dynamic>? ?? const [])
          .map((item) => UsuarioApp.desdeJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
