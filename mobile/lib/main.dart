import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/app/aplicacion_ubbike.dart';
import 'package:ubbike/app/principal/destino_inicial.dart';
import 'package:ubbike/core/servicios/cliente_http.dart';
import 'package:ubbike/core/servicios/fcm_servicio.dart';
import 'package:ubbike/features/incidencias/data/borrador_incidencia.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await inicializarClienteHttp();
  await _inicializarFirebase();
  final incidenciaPendiente = await existeBorradorIncidencia();
  runApp(
    ProviderScope(
      overrides: [
        incidenciaPendienteAlIniciarProvider
            .overrideWith((ref) => incidenciaPendiente),
      ],
      child: const AplicacionUBBike(),
    ),
  );
}

Future<void> _inicializarFirebase() async {
  try {
    await Firebase.initializeApp();
    await FcmServicio.instancia.inicializar();
  } catch (error) {
    if (kDebugMode) {
      debugPrint('Firebase no disponible (push deshabilitado): $error');
    }
  }
}
