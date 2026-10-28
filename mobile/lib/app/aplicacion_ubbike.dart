import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubbike/app/principal/pantalla_principal.dart';
import 'package:ubbike/core/providers/sesion_provider.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/autenticacion/presentation/pantalla_cambio_obligatorio.dart';
import 'package:ubbike/features/autenticacion/presentation/pantalla_inicio_sesion.dart';

class AplicacionUBBike extends StatelessWidget {
  const AplicacionUBBike({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UBBike',
      debugShowCheckedModeBanner: false,
      theme: crearTemaUbb(),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _EnrutadorRaiz(),
    );
  }
}

class _EnrutadorRaiz extends ConsumerWidget {
  const _EnrutadorRaiz();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesionAsync = ref.watch(sesionProvider);

    return sesionAsync.when(
      loading: () => const _PantallaCarga(),
      error: (_, __) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 16),
                const Text(
                    'No pudimos comprobar tu sesión. Tus credenciales siguen guardadas.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: () => ref.invalidate(sesionProvider),
                    child: const Text('Reintentar')),
                TextButton(
                    onPressed: () =>
                        ref.read(sesionProvider.notifier).olvidar(),
                    child: const Text('Usar otra cuenta')),
              ],
            ),
          ),
        ),
      ),
      data: (sesion) => switch (sesion) {
        SesionCargando() => const _PantallaCarga(),
        SesionVacia(:final motivo) =>
          PantallaInicioSesion(mensajeInicial: motivo),
        SesionActiva(:final usuario) when usuario.debeCambiarContrasena =>
          const PantallaCambioObligatorio(),
        SesionActiva() => const PantallaPrincipal(),
      },
    );
  }
}

class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('Iniciando UBBike...'),
          ],
        ),
      ),
    );
  }
}
