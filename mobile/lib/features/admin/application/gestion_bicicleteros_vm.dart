import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/features/admin/data/bicicleteros_admin_repositorio.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

class GestionBicicleterosVm
    extends AutoDisposeAsyncNotifier<List<BicicleteroApp>> {
  @override
  Future<List<BicicleteroApp>> build() {
    ref.listen<int>(
        bicicleterosVersionProvider, (_, __) => _refrescarEnSilencio());
    return ref.read(bicicleterosAdminRepositorioProvider).listar();
  }

  Future<void> _refrescarEnSilencio() async {
    try {
      final bicicleteros =
          await ref.read(bicicleterosAdminRepositorioProvider).listar();
      state = AsyncData(bicicleteros);
    } catch (_) {}
  }

  void recargar() {
    ref.invalidateSelf();
  }

  Future<void> crear({
    required String nombre,
    required String ubicacion,
    required int capacidad,
    double? latitud,
    double? longitud,
  }) async {
    await ref.read(bicicleterosAdminRepositorioProvider).crear(
          nombre: nombre,
          ubicacion: ubicacion,
          capacidad: capacidad,
          latitud: latitud,
          longitud: longitud,
        );
    recargar();
  }

  Future<void> actualizar({
    required String bicicleteroId,
    required String nombre,
    required String ubicacion,
    required int capacidad,
    double? latitud,
    double? longitud,
  }) async {
    await ref.read(bicicleterosAdminRepositorioProvider).actualizar(
          bicicleteroId: bicicleteroId,
          nombre: nombre,
          ubicacion: ubicacion,
          capacidad: capacidad,
          latitud: latitud,
          longitud: longitud,
        );
    recargar();
  }

  Future<void> eliminar(String bicicleteroId) async {
    await ref
        .read(bicicleterosAdminRepositorioProvider)
        .eliminar(bicicleteroId);
    recargar();
  }
}

final gestionBicicleterosVmProvider = AsyncNotifierProvider.autoDispose<
    GestionBicicleterosVm, List<BicicleteroApp>>(GestionBicicleterosVm.new);
