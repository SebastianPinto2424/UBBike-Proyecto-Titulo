import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/bicicletas/data/bicicleta_repositorio.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';

class BicicletasVm {
  const BicicletasVm(this._ref);

  final Ref _ref;

  void _notificarCambio() {
    _ref.read(bicicletasVersionProvider.notifier).state++;
  }

  Future<List<BicicletaApp>> listar() =>
      _ref.read(bicicletaRepositorioProvider).listar();

  Future<BicicletaApp?> obtenerActiva() =>
      _ref.read(bicicletaRepositorioProvider).obtenerActiva();

  Future<void> crear({
    required String descripcion,
    String? marca,
    String? modelo,
    String? color,
    String? aro,
    String? numeroSerie,
    String? fotoUrl,
    bool activar = false,
  }) async {
    await _ref.read(bicicletaRepositorioProvider).crear(
          descripcion: descripcion,
          marca: marca,
          modelo: modelo,
          color: color,
          aro: aro,
          numeroSerie: numeroSerie,
          fotoUrl: fotoUrl,
          activar: activar,
        );
    _notificarCambio();
  }

  Future<void> actualizar({
    required String bicicletaId,
    required String descripcion,
    String? marca,
    String? modelo,
    String? color,
    String? aro,
    String? numeroSerie,
    String? fotoUrl,
    bool actualizarFoto = false,
  }) async {
    await _ref.read(bicicletaRepositorioProvider).actualizar(
          bicicletaId: bicicletaId,
          descripcion: descripcion,
          marca: marca,
          modelo: modelo,
          color: color,
          aro: aro,
          numeroSerie: numeroSerie,
          fotoUrl: fotoUrl,
          actualizarFoto: actualizarFoto,
        );
    _notificarCambio();
  }

  Future<void> eliminar(String bicicletaId) async {
    await _ref.read(bicicletaRepositorioProvider).eliminar(bicicletaId);
    _notificarCambio();
  }

  Future<void> activar(String bicicletaId) async {
    await _ref.read(bicicletaRepositorioProvider).activar(bicicletaId);
    _notificarCambio();
  }

  Future<void> desactivar(String bicicletaId) async {
    await _ref.read(bicicletaRepositorioProvider).desactivar(bicicletaId);
    _notificarCambio();
  }
}

final bicicletasVmProvider = Provider.autoDispose<BicicletasVm>(
  (ref) => BicicletasVm(ref),
);
