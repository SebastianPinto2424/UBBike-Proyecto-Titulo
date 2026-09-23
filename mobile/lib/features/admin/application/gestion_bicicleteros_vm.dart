import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/providers/repositorios_provider.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

class GestionBicicleterosVm
    extends AutoDisposeAsyncNotifier<List<BicicleteroApp>> {
  @override
  Future<List<BicicleteroApp>> build() {
    return ref.read(bicicleterosAdminRepositoryProvider).listar();
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
    await ref.read(bicicleterosAdminRepositoryProvider).crear(
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
    await ref.read(bicicleterosAdminRepositoryProvider).actualizar(
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
    await ref.read(bicicleterosAdminRepositoryProvider).eliminar(bicicleteroId);
    recargar();
  }
}

final gestionBicicleterosVmProvider = AsyncNotifierProvider.autoDispose<
    GestionBicicleterosVm, List<BicicleteroApp>>(GestionBicicleterosVm.new);
