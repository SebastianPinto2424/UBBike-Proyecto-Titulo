import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/features/acceso/data/acceso_repository.dart';
import 'package:ubbike/features/acceso/data/acceso_modelos.dart';
import 'package:ubbike/shared/modelos/movimiento_app.dart';

class EscanerQrVm {
  const EscanerQrVm(this._ref);

  final Ref _ref;

  Future<QrValidadoApp> validarQr(String token) =>
      _ref.read(accesoRepositoryProvider).validarQr(token);

  Future<void> liberarQr(String token) =>
      _ref.read(accesoRepositoryProvider).liberarQr(token);

  Future<MovimientoApp> confirmarQr(String token, {String? comentario}) =>
      _ref.read(accesoRepositoryProvider).confirmarQr(
            token,
            comentario: comentario,
          );

  Future<MovimientoApp> denegarQr({
    required String token,
    required String motivo,
  }) =>
      _ref.read(accesoRepositoryProvider).denegarQr(
            token: token,
            motivo: motivo,
          );
}

final escanerQrVmProvider = Provider.autoDispose<EscanerQrVm>(
  (ref) => EscanerQrVm(ref),
);
