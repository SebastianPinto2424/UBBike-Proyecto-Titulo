import '../apoyo/configurar-entorno';
import { construirStatsBicicletero } from '../../src/modulos/bicicleteros/bicicletero.ocupacion';
import type { Bicicletero } from '../../src/generated/prisma/client';

const bicicletero = (capacidad: number): Bicicletero =>
  ({
    id: 'bic-1',
    nombre: 'Bicicletero FACE',
    ubicacion: 'FACE',
    capacidad
  }) as Bicicletero;

describe('construirStatsBicicletero', () => {
  it('calcula cupos y porcentaje en un caso normal', () => {
    const stats = construirStatsBicicletero(bicicletero(50), 10);
    expect(stats.capacidad).toBe(50);
    expect(stats.ocupados).toBe(10);
    expect(stats.cuposDisponibles).toBe(40);
    expect(stats.porcentajeUso).toBe(20);
  });

  it('no devuelve cupos disponibles negativos si hay sobreocupación', () => {
    const stats = construirStatsBicicletero(bicicletero(5), 8);
    expect(stats.cuposDisponibles).toBe(0);
    expect(stats.porcentajeUso).toBe(100);
  });

  it('evita división por cero clampeando la capacidad a mínimo 1', () => {
    const stats = construirStatsBicicletero(bicicletero(0), 0);
    expect(stats.capacidad).toBe(1);
    expect(stats.porcentajeUso).toBe(0);
    expect(stats.cuposDisponibles).toBe(1);
  });
});
