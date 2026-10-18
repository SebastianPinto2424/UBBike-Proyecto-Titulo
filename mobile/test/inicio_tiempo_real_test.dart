import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/core/providers/versiones_provider.dart';
import 'package:ubbike/core/tema/tema_ubb.dart';
import 'package:ubbike/features/inicio/application/inicio_usuario_vm.dart';
import 'package:ubbike/features/inicio/presentation/vista_inicio_usuario.dart';
import 'package:ubbike/shared/modelos/bicicleta_app.dart';
import 'package:ubbike/shared/modelos/bicicletero_app.dart';

class _VmBicicletaQueSale extends InicioUsuarioVm {
  _VmBicicletaQueSale(super.ref, this.estado);

  final ValueNotifier<bool> estado;

  @override
  Future<BicicletaApp?> obtenerActiva() async => BicicletaApp(
        id: 'bici-1',
        descripcion: 'Bici roja',
        activa: true,
        dentroBicicletero: estado.value,
      );

  @override
  Future<List<BicicleteroApp>> listarBicicleteros() async => const [];
}

void main() {
  testWidgets('tras un retiro el inicio deja de mostrar la bicicleta dentro',
      (tester) async {
    final dentro = ValueNotifier(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inicioUsuarioVmProvider
              .overrideWith((ref) => _VmBicicletaQueSale(ref, dentro)),
        ],
        child: MaterialApp(
          theme: crearTemaUbb(),
          home: const Scaffold(body: VistaInicioUsuario()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bicicleta dentro del bicicletero'), findsOneWidget);

    dentro.value = false;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VistaInicioUsuario)),
    );
    container.read(movimientosVersionProvider.notifier).state++;
    await tester.pumpAndSettle();

    expect(find.text('Bicicleta fuera del bicicletero'), findsOneWidget);
    expect(find.text('Bicicleta dentro del bicicletero'), findsNothing);
  });
}
