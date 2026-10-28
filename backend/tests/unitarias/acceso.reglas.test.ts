import '../apoyo/configurar-entorno';
import {
  validarBicicleteroDelRetiro,
  validarReglaMovimiento
} from '../../src/modulos/acceso/operaciones/acceso.reglas';
import { TipoMovimiento } from '../../src/modulos/historial/tipo-movimiento';

describe('validarReglaMovimiento', () => {
  it('lanza 409 si intenta INGRESO y bicicleta ya esta dentro', () => {
    expect(() =>
      validarReglaMovimiento({ dentroBicicletero: true }, TipoMovimiento.INGRESO)
    ).toThrow('La bicicleta ya registra ingreso activo');
  });

  it('lanza 409 si intenta RETIRO y bicicleta no esta dentro', () => {
    expect(() =>
      validarReglaMovimiento({ dentroBicicletero: false }, TipoMovimiento.RETIRO)
    ).toThrow('La bicicleta no registra ingreso activo');
  });

  it('no lanza si INGRESO y bicicleta esta fuera', () => {
    expect(() =>
      validarReglaMovimiento({ dentroBicicletero: false }, TipoMovimiento.INGRESO)
    ).not.toThrow();
  });

  it('no lanza si RETIRO y bicicleta esta dentro', () => {
    expect(() =>
      validarReglaMovimiento({ dentroBicicletero: true }, TipoMovimiento.RETIRO)
    ).not.toThrow();
  });
});

describe('validarBicicleteroDelRetiro', () => {
  const bicicletaEnA = {
    dentroBicicletero: true,
    bicicleteroActualId: 'bicicletero-a'
  };

  it('lanza 409 si el retiro se intenta en un bicicletero distinto al de ingreso', () => {
    expect(() =>
      validarBicicleteroDelRetiro(bicicletaEnA, TipoMovimiento.RETIRO, 'bicicletero-b')
    ).toThrow('La bicicleta está registrada en otro bicicletero');
  });

  it('no lanza si el retiro se hace en el mismo bicicletero donde ingreso', () => {
    expect(() =>
      validarBicicleteroDelRetiro(bicicletaEnA, TipoMovimiento.RETIRO, 'bicicletero-a')
    ).not.toThrow();
  });

  it('no aplica la regla a los ingresos', () => {
    expect(() =>
      validarBicicleteroDelRetiro(
        { dentroBicicletero: false, bicicleteroActualId: null },
        TipoMovimiento.INGRESO,
        'bicicletero-b'
      )
    ).not.toThrow();
  });

  it('no lanza si la bicicleta no tiene bicicletero registrado', () => {
    expect(() =>
      validarBicicleteroDelRetiro(
        { dentroBicicletero: true, bicicleteroActualId: null },
        TipoMovimiento.RETIRO,
        'bicicletero-b'
      )
    ).not.toThrow();
  });
});
