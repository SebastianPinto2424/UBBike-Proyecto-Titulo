import '../helpers/env-setup';
import { prismaMock } from '../helpers/prisma-mock';

import { crearBicicletero } from '../../src/modulos/bicicleteros/bicicletero.servicio';

const bicicletero = {
  id: 'bic-1',
  nombre: 'Bicicletero el Boldo',
  ubicacion: 'Sector antiguo',
  capacidad: 40,
  latitud: null,
  longitud: null,
  activo: false,
  creadoEn: new Date(),
  actualizadoEn: new Date()
};

const datosNuevos = {
  nombre: 'Bicicletero el Boldo',
  ubicacion: 'Frente a la biblioteca',
  capacidad: 80,
  latitud: -36.82,
  longitud: -73.01
};

describe('crear un bicicletero con el nombre de uno eliminado', () => {
  beforeEach(() => {
    prismaMock.bicicleta.count.mockResolvedValue(0 as never);
  });

  it('reactiva el existente con los datos nuevos en vez de fallar', async () => {
    prismaMock.bicicletero.findUnique.mockResolvedValue(bicicletero as never);
    prismaMock.bicicletero.update.mockResolvedValue({
      ...bicicletero,
      ...datosNuevos,
      activo: true
    } as never);

    const resultado = await crearBicicletero(datosNuevos);

    expect(prismaMock.bicicletero.create).not.toHaveBeenCalled();
    expect(prismaMock.bicicletero.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'bic-1' },
        data: expect.objectContaining({ activo: true, capacidad: 80 })
      })
    );
    expect(resultado.nombre).toBe('Bicicletero el Boldo');
    expect(resultado.capacidad).toBe(80);
  });

  it('rechaza el nombre si el bicicletero sigue activo', async () => {
    prismaMock.bicicletero.findUnique.mockResolvedValue({
      ...bicicletero,
      activo: true
    } as never);

    await expect(crearBicicletero(datosNuevos)).rejects.toMatchObject({
      statusCode: 409
    });
    expect(prismaMock.bicicletero.create).not.toHaveBeenCalled();
    expect(prismaMock.bicicletero.update).not.toHaveBeenCalled();
  });

  it('crea uno nuevo cuando el nombre esta libre', async () => {
    prismaMock.bicicletero.findUnique.mockResolvedValue(null as never);
    prismaMock.bicicletero.create.mockResolvedValue({
      ...bicicletero,
      ...datosNuevos,
      id: 'bic-2',
      activo: true
    } as never);

    const resultado = await crearBicicletero(datosNuevos);

    expect(prismaMock.bicicletero.create).toHaveBeenCalled();
    expect(resultado.id).toBe('bic-2');
  });
});
