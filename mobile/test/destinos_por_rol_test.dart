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

  test('el guardia valida accesos desde el centro y atiende avisos', () {
    expect(
      _etiquetas(RolUsuario.guardia),
      ['Inicio', 'Historial', 'Validar', 'Avisos', 'Mi cuenta'],
    );
  });

  test('central supervisa movimientos y guardias sin validar accesos', () {
    final etiquetas = _etiquetas(RolUsuario.adminCentral);

    expect(
      etiquetas,
      ['Inicio', 'Movimientos', 'Guardias', 'Soporte', 'Mi cuenta'],
    );
    expect(etiquetas, isNot(contains('Validar')));
    expect(etiquetas, isNot(contains('QR')));
  });

  test('el administrador valida desde el centro y atiende soporte', () {
    expect(
      _etiquetas(RolUsuario.administrador),
      ['Inicio', 'Soporte', 'Validar', 'Gestión', 'Mi cuenta'],
    );
  });

  test(
      'ninguna barra pasa de cinco destinos y la acción principal va al centro',
      () {
    for (final rol in RolUsuario.values) {
      final etiquetas = _etiquetas(rol);
      expect(etiquetas, hasLength(5), reason: '$rol');
      expect(etiquetas.first, 'Inicio', reason: '$rol');
      expect(
        etiquetas[indicePerfil],
        rol.esUsuarioRegular ? 'Perfil' : 'Mi cuenta',
        reason: '$rol',
      );
    }
    for (final rol in [RolUsuario.guardia, RolUsuario.administrador]) {
      expect(_etiquetas(rol)[indiceValidar], 'Validar', reason: '$rol');
    }
  });

  test('los títulos acompañan a cada destino de la barra', () {
    for (final rol in RolUsuario.values) {
      expect(
        titulosPorRol(rol).map((titulo) => titulo.$2).toList(),
        _etiquetas(rol),
        reason: '$rol',
      );
    }
  });

  test('los índices compartidos apuntan a la sección de cada rol', () {
    for (final rol in RolUsuario.values) {
      expect(
        _etiquetas(rol)[indiceSoportePorRol(rol)],
        rol == RolUsuario.guardia ? 'Avisos' : 'Soporte',
        reason: '$rol',
      );
    }
    expect(
      _etiquetas(RolUsuario.administrador)[indiceGestionAdministrador],
      'Gestión',
    );
  });

  test('guardia, central y administrador usan el destino Mi cuenta', () {
    expect(
      RolUsuario.values.where(usaDestinoMiCuenta),
      unorderedEquals([
        RolUsuario.guardia,
        RolUsuario.adminCentral,
        RolUsuario.administrador,
      ]),
    );
  });
}
