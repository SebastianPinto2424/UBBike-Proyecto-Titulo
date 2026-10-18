import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/historial/data/historial_repository.dart';
import 'package:ubbike/features/incidencias/data/incidencia_repository.dart';
import 'package:ubbike/shared/modelos/historial_modelos.dart';
import 'package:ubbike/shared/modelos/incidencia_modelos.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';
import 'package:ubbike/shared/utils/refresco_coalescido.dart';
import 'package:ubbike/shared/modelos/dashboard_modelos.dart';
import 'package:ubbike/shared/data/bicicleteros_repository.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';

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
    ref.listen<int>(
        bicicleterosVersionProvider, (_, __) => refresco.solicitar());
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
  final incidenciaRepository = ref.read(incidenciaRepositoryProvider);

  final resumenFuture = historialRepository.resumen(periodo: periodo);
  final bicicleterosFuture = ref.read(bicicleterosRepositoryProvider).listar();
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
