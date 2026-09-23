import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/acceso/application/solicitudes_guardia_vm.dart';
import 'package:ubbike/features/admin/application/gestion_usuarios_vm.dart';
import 'package:ubbike/features/historial/application/movimientos_vm.dart';
import 'package:ubbike/features/inicio/application/dashboard_central_vm.dart';
import 'package:ubbike/features/incidencias/application/incidencias_vm.dart';
import 'package:ubbike/shared/modelos/usuario_app.dart';
import 'package:ubbike/shared/utils/refresco_coalescido.dart';

class DatosDashboardAdministrador {
  const DatosDashboardAdministrador({
    required this.central,
    this.usuarios = const [],
  });

  final DatosDashboardCentral central;
  final List<UsuarioApp> usuarios;

  int get usuariosActivos => central.resumen.usuariosActivos;

  int get usuariosInactivos => central.resumen.usuariosInactivos;

  int get usuariosPendientesVerificacion =>
      central.resumen.usuariosSinVerificar;
}

final periodoDashboardAdministradorProvider =
    StateProvider.autoDispose<String>((ref) => 'SEMANA');

class DashboardAdministradorVm
    extends AutoDisposeAsyncNotifier<DatosDashboardAdministrador> {
  late RefrescoCoalescido _refresco;
  int _revision = 0;
  bool desactualizado = false;

  @override
  Future<DatosDashboardAdministrador> build() {
    final periodo = ref.watch(periodoDashboardAdministradorProvider);
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
    ref.listen<int>(usuariosVersionProvider, (_, __) => refresco.solicitar());
    return _cargar(periodo);
  }

  Future<DatosDashboardAdministrador> _cargar(String periodo) async {
    return DatosDashboardAdministrador(
      central: await cargarDashboardCentral(ref, periodo),
    );
  }

  Future<void> refrescar() => _refresco.solicitar();

  Future<void> _refrescar() async {
    final revision = _revision;
    try {
      final datos =
          await _cargar(ref.read(periodoDashboardAdministradorProvider));
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
          : AsyncData(DatosDashboardAdministrador(
              central: anterior.central.marcarDesactualizado()));
    }
  }

  void cambiarPeriodo(String valor) {
    ref.read(periodoDashboardAdministradorProvider.notifier).state = valor;
  }
}

final dashboardAdministradorVmProvider = AsyncNotifierProvider.autoDispose<
    DashboardAdministradorVm,
    DatosDashboardAdministrador>(DashboardAdministradorVm.new);
