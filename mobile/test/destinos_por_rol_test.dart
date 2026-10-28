import 'package:flutter_test/flutter_test.dart';
import 'package:ubbike/app/principal/destinos_por_rol.dart';
import 'package:ubbike/core/modelos/rol_usuario.dart';

List<String> _etiquetas(RolUsuario rol) =>
    destinosPorRol(rol).map((destino) => destino.label).toList();

void main() {
  test('estudiantes y funcionarios ven su bicicleta y su QR', () {
    for (final rol in [RolUsuario.estudiante, RolUsuario.funcionario]) {
      expect(
        _etiquetas(rol),
        ['Inicio', 'Bicicletas', 'QR', 'Soporte', 'Perfil'],
      );
    }
  });

  test('el guardia valida accesos y atiende avisos', () {
    expect(
      _etiquetas(RolUsuario.guardia),
      ['Inicio', 'Historial', 'Validar', 'Avisos', 'Perfil'],
    );
  });

  test('central supervisa movimientos y guardias sin validar accesos', () {
    final etiquetas = _etiquetas(RolUsuario.adminCentral);

    expect(
      etiquetas,
      ['Inicio', 'Movimientos', 'Guardias', 'Soporte', 'Perfil'],
    );
    expect(etiquetas, isNot(contains('Validar')));
    expect(etiquetas, isNot(contains('QR')));
  });

  test('el administrador accede a todo y a la gestión', () {
    expect(
      _etiquetas(RolUsuario.administrador),
      ['Inicio', 'Bicicletas', 'Validar', 'Soporte', 'Gestión', 'Perfil'],
    );
  });

  test('todos los roles parten en Inicio y terminan en Perfil', () {
    for (final rol in RolUsuario.values) {
      final etiquetas = _etiquetas(rol);
      expect(etiquetas.first, 'Inicio', reason: '$rol');
      expect(etiquetas.last, 'Perfil', reason: '$rol');
    }
  });
}
