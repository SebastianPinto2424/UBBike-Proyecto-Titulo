import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/inicio/application/tablero_central_vm.dart';
import 'package:ubbike/core/modelos/usuario_app.dart';
import 'package:ubbike/shared/utilidades/refresco_coalescido.dart';
import 'package:ubbike/shared/modelos/tablero_modelos.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';

class DatosTableroAdministrador {
  const DatosTableroAdministrador({
    required this.central,
    this.usuarios = const [],
  });

  final DatosTableroCentral central;
  final List<UsuarioApp> usuarios;

  int get usuariosActivos => central.resumen.usuariosActivos;

  int get usuariosInactivos => central.resumen.usuariosInactivos;

  int get usuariosPendientesVerificacion =>
      central.resumen.usuariosSinVerificar;
}

final periodoTableroAdministradorProvider =
    StateProvider.autoDispose<String>((ref) => 'SEMANA');

class TableroAdministradorVm
    extends AutoDisposeAsyncNotifier<DatosTableroAdministrador> {
  late RefrescoCoalescido _refresco;
  int _revision = 0;
  bool desactualizado = false;

  @override
  Future<DatosTableroAdministrador> build() {
    final periodo = ref.watch(periodoTableroAdministradorProvider);
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
    ref.listen<int>(usuariosVersionProvider, (_, __) => refresco.solicitar());
    return _cargar(periodo);
  }

  Future<DatosTableroAdministrador> _cargar(String periodo) async {
    return DatosTableroAdministrador(
      central: await cargarTableroCentral(ref, periodo),
    );
  }

  Future<void> refrescar() => _refresco.solicitar();

  Future<void> _refrescar() async {
    final revision = _revision;
    try {
      final datos =
          await _cargar(ref.read(periodoTableroAdministradorProvider));
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
          : AsyncData(DatosTableroAdministrador(
              central: anterior.central.marcarDesactualizado()));
    }
  }

  void cambiarPeriodo(String valor) {
    ref.read(periodoTableroAdministradorProvider.notifier).state = valor;
  }
}

final tableroAdministradorVmProvider = AsyncNotifierProvider.autoDispose<
    TableroAdministradorVm,
    DatosTableroAdministrador>(TableroAdministradorVm.new);
