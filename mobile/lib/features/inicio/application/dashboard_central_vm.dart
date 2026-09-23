import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/repositorios_provider.dart';
import 'package:ubbike/features/acceso/data/solicitud_guardia_modelos.dart';
import 'package:ubbike/features/acceso/application/solicitudes_guardia_vm.dart';
import 'package:ubbike/features/historial/application/movimientos_vm.dart';
import 'package:ubbike/features/historial/data/historial_modelos.dart';
import 'package:ubbike/features/incidencias/application/incidencias_vm.dart';
import 'package:ubbike/features/incidencias/data/incidencia_modelos.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/utils/refresco_coalescido.dart';

class DatosDashboardCentral {
  const DatosDashboardCentral({
    required this.resumen,
    required this.bicicleteros,
    required this.solicitudes,
    required this.incidencias,
    required this.movimientosRecientes,
    this.actualizadoEn,
    this.desactualizado = false,
  });

  final ResumenHistorialApp resumen;
  final List<BicicleteroApp> bicicleteros;
  final List<SolicitudGuardiaApp> solicitudes;
  final List<IncidenciaApp> incidencias;
  final List<MovimientoApp> movimientosRecientes;
  final DateTime? actualizadoEn;
  final bool desactualizado;
  int get totalIncidenciasAbiertas => resumen.incidenciasAbiertas;
  int get totalSolicitudesAbiertas => resumen.solicitudesAbiertas;

  DatosDashboardCentral marcarDesactualizado() => DatosDashboardCentral(
        resumen: resumen,
        bicicleteros: bicicleteros,
        solicitudes: solicitudes,
        incidencias: incidencias,
        movimientosRecientes: movimientosRecientes,
        actualizadoEn: actualizadoEn,
        desactualizado: true,
      );

  int get capacidadTotal =>
      bicicleteros.fold(0, (total, item) => total + item.capacidad);

  int get ocupadosTotal =>
      bicicleteros.fold(0, (total, item) => total + item.ocupados);

  int get cuposDisponiblesTotal =>
      bicicleteros.fold(0, (total, item) => total + item.cuposDisponibles);

  double get usoCampus => capacidadTotal == 0
      ? 0.0
      : (ocupadosTotal / capacidadTotal).clamp(0.0, 1.0).toDouble();

  List<SolicitudGuardiaApp> get solicitudesAbiertas => solicitudes
      .where((s) => s.estado != 'RESUELTA' && s.estado != 'CANCELADA')
      .toList();

  List<IncidenciaApp> get incidenciasAbiertas => incidencias
      .where((i) => i.estado != 'RESUELTA' && i.estado != 'DESCARTADA')
      .toList();

  List<BicicleteroApp> get bicicleterosCriticos {
    final lista = bicicleteros
        .where((b) => b.porcentajeUso >= 75 || b.cuposDisponibles <= 5)
        .toList()
      ..sort((a, b) => b.porcentajeUso.compareTo(a.porcentajeUso));
    return lista;
  }
}

final periodoDashboardCentralProvider =
    StateProvider.autoDispose<String>((ref) => 'SEMANA');

class DashboardCentralVm
    extends AutoDisposeAsyncNotifier<DatosDashboardCentral> {
  late RefrescoCoalescido _refresco;
  int _revision = 0;
  bool desactualizado = false;

  @override
  Future<DatosDashboardCentral> build() {
    final periodo = ref.watch(periodoDashboardCentralProvider);
    _revision++;
    desactualizado = false;
    final refresco = RefrescoCoalescido(
      alRefrescar: _refrescar,
      detectarFallo: () => desactualizado,
    )..iniciarRespaldo();
    _refresco = refresco;
    ref.onDispose(() {
      _revision++;
      refresco.detener();
    });
    ref.listen<int>(
        incidenciasVersionProvider, (_, __) => refresco.solicitar());
    ref.listen<int>(
        solicitudesGuardiaVersionProvider, (_, __) => refresco.solicitar());
    ref.listen<int>(
        movimientosVersionProvider, (_, __) => refresco.solicitar());
    return _cargar(periodo);
  }

  Future<DatosDashboardCentral> _cargar(String periodo) =>
      cargarDashboardCentral(ref, periodo);

  Future<void> refrescar() => _refresco.solicitar();

  Future<void> _refrescar() async {
    final revision = _revision;
    try {
      final datos = await _cargar(ref.read(periodoDashboardCentralProvider));
      if (revision == _revision) {
        desactualizado = false;
        state = AsyncData(datos);
      }
    } catch (error, stackTrace) {
      if (revision != _revision) return;
      desactualizado = true;
      final anterior = state.valueOrNull;
      state = anterior == null
          ? AsyncError(error, stackTrace)
          : AsyncData(anterior.marcarDesactualizado());
    }
  }

  void cambiarPeriodo(String valor) {
    ref.read(periodoDashboardCentralProvider.notifier).state = valor;
  }
}

Future<DatosDashboardCentral> cargarDashboardCentral(
    Ref ref, String periodo) async {
  final historialRepository = ref.read(historialRepositoryProvider);
  final solicitudGuardiaRepository =
      ref.read(solicitudGuardiaRepositoryProvider);
  final incidenciaRepository = ref.read(incidenciaRepositoryProvider);

  final resumenFuture = historialRepository.resumen(periodo: periodo);
  final bicicleterosFuture = solicitudGuardiaRepository.listarBicicleteros();
  final incidenciasFuture =
      incidenciaRepository.listar(estado: 'ABIERTAS', limite: 3);
  final movimientosFuture =
      historialRepository.listar(periodo: 'DIA', limite: 3);

  final resultados = await Future.wait<Object>([
    resumenFuture,
    bicicleterosFuture,
    incidenciasFuture,
    movimientosFuture
  ]);
  return DatosDashboardCentral(
    resumen: resultados[0] as ResumenHistorialApp,
    bicicleteros: resultados[1] as List<BicicleteroApp>,
    solicitudes: const [],
    incidencias: resultados[2] as List<IncidenciaApp>,
    movimientosRecientes: resultados[3] as List<MovimientoApp>,
    actualizadoEn: DateTime.now(),
  );
}

final dashboardCentralVmProvider = AsyncNotifierProvider.autoDispose<
    DashboardCentralVm, DatosDashboardCentral>(DashboardCentralVm.new);
