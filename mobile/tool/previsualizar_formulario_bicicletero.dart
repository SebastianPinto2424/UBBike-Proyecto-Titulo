import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/admin/presentation/formulario_bicicletero_sheet.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

void main() => runApp(ProviderScope(
        child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: crearTemaUbb(),
      home: Builder(
          builder: (context) => Scaffold(
                appBar:
                    AppBar(title: const Text('Vista previa · Bicicleteros')),
                body: Center(
                    child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                              'Modo de prueba: no conecta con el backend ni guarda cambios.'),
                          const SizedBox(height: 20),
                          for (final editar in [false, true])
                            Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ElevatedButton(
                                    onPressed: () => showModalBottomSheet<bool>(
                                          context: context,
                                          showDragHandle: true,
                                          isScrollControlled: true,
                                          useSafeArea: true,
                                          builder: (_) =>
                                              FormularioBicicleteroSheet(
                                            bicicletero: editar
                                                ? BicicleteroApp.desdeJson({
                                                    'id': 'ejemplo',
                                                    'nombre':
                                                        'Bicicletero FACE',
                                                    'ubicacion':
                                                        'Junto al acceso principal de FACE',
                                                    'capacidad': 80,
                                                    'latitud':
                                                        -36.82141385290648,
                                                    'longitud':
                                                        -73.01254820745834
                                                  })
                                                : null,
                                            alGuardar: (_) async =>
                                                Future<void>.delayed(
                                                    const Duration(
                                                        milliseconds: 400)),
                                          ),
                                        ),
                                    child: Text(editar
                                        ? 'Editar ejemplo'
                                        : 'Nuevo bicicletero'))),
                        ],
                      )),
                )),
              )),
    )));
