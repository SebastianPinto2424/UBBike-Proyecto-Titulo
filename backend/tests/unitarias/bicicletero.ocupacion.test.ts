import '../apoyo/configurar-entorno';
import { construirEstadisticasBicicletero } from '../../src/modulos/bicicleteros/bicicletero.ocupacion';
import type { Bicicletero } from '../../src/generated/prisma/client';

const bicicletero = (capacidad: number): Bicicletero =>
  ({
    id: 'bic-1',
    nombre: 'Bicicletero FACE',
    ubicacion: 'FACE',
    capacidad
  }) as Bicicletero;

describe('construirEstadisticasBicicletero', () => {
  it('calcula cupos y porcentaje en un caso normal', () => {
    const estadisticas = construirEstadisticasBicicletero(bicicletero(50), 10);
    expect(estadisticas.capacidad).toBe(50);
    expect(estadisticas.ocupados).toBe(10);
    expect(estadisticas.cuposDisponibles).toBe(40);
    expect(estadisticas.porcentajeUso).toBe(20);
  });

  it('no devuelve cupos disponibles negativos si hay sobreocupación', () => {
    const estadisticas = construirEstadisticasBicicletero(bicicletero(5), 8);
    expect(estadisticas.cuposDisponibles).toBe(0);
    expect(estadisticas.porcentajeUso).toBe(100);
  });

  it('evita división por cero clampeando la capacidad a mínimo 1', () => {
    const estadisticas = construirEstadisticasBicicletero(bicicletero(0), 0);
    expect(estadisticas.capacidad).toBe(1);
    expect(estadisticas.porcentajeUso).toBe(0);
    expect(estadisticas.cuposDisponibles).toBe(1);
  });
});
