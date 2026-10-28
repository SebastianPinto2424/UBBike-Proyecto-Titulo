import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/bicicletas/data/bicicleta_repositorio.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/data/bicicleteros_repositorio.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

class InicioUsuarioVm {
  const InicioUsuarioVm(this._ref);

  final Ref _ref;

  Future<BicicletaApp?> obtenerActiva() =>
      _ref.read(bicicletaRepositorioProvider).obtenerActiva();

  Future<List<BicicleteroApp>> listarBicicleteros() =>
      _ref.read(bicicleterosRepositorioProvider).listar();
}

final inicioUsuarioVmProvider = Provider.autoDispose<InicioUsuarioVm>(
  (ref) => InicioUsuarioVm(ref),
);
