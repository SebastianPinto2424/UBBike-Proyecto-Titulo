import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EstadoConexion { conectando, conectado, desconectado }

final conexionProvider =
    StateProvider<EstadoConexion>((ref) => EstadoConexion.desconectado);
