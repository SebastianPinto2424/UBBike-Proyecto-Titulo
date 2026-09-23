import '../helpers/env-setup';
import { prismaMock } from '../helpers/prisma-mock';
import {
  actualizarBicicletero,
  crearBicicletero,
  eliminarBicicletero
} from '../../src/modulos/bicicleteros/bicicletero.servicio';
import type { Bicicletero } from '../../src/generated/prisma/client';

const bicicleteroBase = {
  id: 'bic-1',
  nombre: 'Bicicletero FACE',
  ubicacion: 'Sector FACE',
  latitud: null,
  longitud: null,
  capacidad: 120,
  activo: true
} as Bicicletero;

describe('crearBicicletero', () => {
  it('guarda el bicicletero y lo devuelve sin ocupación', async () => {
    prismaMock.bicicletero.create.mockResolvedValue(bicicleteroBase);

    const resultado = await crearBicicletero({
      nombre: bicicleteroBase.nombre,
      ubicacion: bicicleteroBase.ubicacion,
      capacidad: 120
    });

    expect(resultado.ocupados).toBe(0);
    expect(resultado.cuposDisponibles).toBe(120);
    expect(prismaMock.bicicletero.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        nombre: bicicleteroBase.nombre,
        capacidad: 120,
        latitud: null,
        longitud: null
      })
    });
  });
});

describe('actualizarBicicletero', () => {
  it('lanza 404 si el bicicletero no existe', async () => {
    prismaMock.bicicletero.findUnique.mockResolvedValue(null);

    await expect(
      actualizarBicicletero('bic-inexistente', { nombre: 'Otro nombre' })
    ).rejects.toMatchObject({ statusCode: 404 });
    expect(prismaMock.bicicletero.update).not.toHaveBeenCalled();
  });

  it('actualiza y recalcula la ocupación actual', async () => {
    prismaMock.bicicletero.findUnique.mockResolvedValue(bicicleteroBase);
    prismaMock.bicicletero.update.mockResolvedValue({
      ...bicicleteroBase,
      capacidad: 100
    } as Bicicletero);
    prismaMock.bicicleta.count.mockResolvedValue(25);

    const resultado = await actualizarBicicletero('bic-1', { capacidad: 100 });

    expect(resultado.capacidad).toBe(100);
    expect(resultado.ocupados).toBe(25);
    expect(resultado.cuposDisponibles).toBe(75);
  });
});

describe('eliminarBicicletero', () => {
  it('lanza 409 si todavía hay bicicletas dentro', async () => {
    prismaMock.bicicletero.findUnique.mockResolvedValue(bicicleteroBase);
    prismaMock.bicicleta.count.mockResolvedValue(3);

    await expect(eliminarBicicletero('bic-1')).rejects.toMatchObject({
      statusCode: 409
    });
    expect(prismaMock.bicicletero.update).not.toHaveBeenCalled();
  });

  it('desactiva el bicicletero cuando está vacío', async () => {
    prismaMock.bicicletero.findUnique.mockResolvedValue(bicicleteroBase);
    prismaMock.bicicleta.count.mockResolvedValue(0);
    prismaMock.bicicletero.update.mockResolvedValue({
      ...bicicleteroBase,
      activo: false
    } as Bicicletero);

    const resultado = await eliminarBicicletero('bic-1');

    expect(resultado.message).toContain('eliminado correctamente');
    expect(prismaMock.bicicletero.update).toHaveBeenCalledWith({
      where: { id: 'bic-1' },
      data: { activo: false }
    });
  });
});
