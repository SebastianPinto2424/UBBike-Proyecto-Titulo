import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/core/servicios/cliente_api.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';

final clienteApiProvider = Provider<ClienteApi>((ref) {
  ref.watch(sesionProvider);

  EstadoSesion? sesionActual() => ref.read(sesionProvider).value;

  return ClienteApi(
    obtenerToken: () => switch (sesionActual()) {
      SesionActiva(:final token) => token,
      _ => null,
    },
    obtenerRefreshToken: () => switch (sesionActual()) {
      SesionActiva(:final refreshToken) => refreshToken,
      _ => null,
    },
    obtenerUsuarioId: () => switch (sesionActual()) {
      SesionActiva(:final usuario) => usuario.id,
      _ => null,
    },
    alActualizarTokens: (token, refreshToken) =>
        ref.read(sesionProvider.notifier).actualizarToken(token, refreshToken),
    alExpirarSesion: () => ref.read(sesionProvider.notifier).olvidar(
          motivo: mensajeSesionExpirada,
        ),
  );
});
