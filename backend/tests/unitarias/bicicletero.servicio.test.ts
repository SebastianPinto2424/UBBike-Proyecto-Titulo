import '../apoyo/configurar-entorno';
import { prismaSimulado } from '../apoyo/prisma-simulado';

jest.mock('../../src/tiempo-real/tiempo-real', () => ({
  ...jest.requireActual('../../src/tiempo-real/tiempo-real'),
  emitirATodos: jest.fn()
}));

import { emitirATodos } from '../../src/tiempo-real/tiempo-real';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';
import {
  actualizarBicicletero,
  crearBicicletero,
  eliminarBicicletero,
  listarBicicleteros
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
    prismaSimulado.bicicletero.create.mockResolvedValue(bicicleteroBase);

    const resultado = await crearBicicletero({
      nombre: bicicleteroBase.nombre,
      ubicacion: bicicleteroBase.ubicacion,
      capacidad: 120
    });

    expect(resultado.ocupados).toBe(0);
    expect(resultado.cuposDisponibles).toBe(120);
    expect(emitirATodos).toHaveBeenCalledWith('bicicleteros');
    expect(prismaSimulado.bicicletero.create).toHaveBeenCalledWith({
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
    prismaSimulado.bicicletero.findUnique.mockResolvedValue(null);

    await expect(
      actualizarBicicletero('bic-inexistente', { nombre: 'Otro nombre' })
    ).rejects.toMatchObject({ statusCode: 404 });
    expect(prismaSimulado.bicicletero.update).not.toHaveBeenCalled();
  });

  it('actualiza y recalcula la ocupación actual', async () => {
    prismaSimulado.bicicletero.findUnique.mockResolvedValue(bicicleteroBase);
    prismaSimulado.bicicletero.update.mockResolvedValue({
      ...bicicleteroBase,
      capacidad: 100
    } as Bicicletero);
    prismaSimulado.bicicleta.count.mockResolvedValue(25);

    const resultado = await actualizarBicicletero('bic-1', { capacidad: 100 });

    expect(resultado.capacidad).toBe(100);
    expect(resultado.ocupados).toBe(25);
    expect(resultado.cuposDisponibles).toBe(75);
    expect(emitirATodos).toHaveBeenCalledWith('bicicleteros');
  });
});

describe('eliminarBicicletero', () => {
  it('lanza 409 si todavía hay bicicletas dentro', async () => {
    prismaSimulado.bicicletero.findUnique.mockResolvedValue(bicicleteroBase);
    prismaSimulado.bicicleta.count.mockResolvedValue(3);

    await expect(eliminarBicicletero('bic-1')).rejects.toMatchObject({
      statusCode: 409
    });
    expect(prismaSimulado.bicicletero.update).not.toHaveBeenCalled();
  });

  it('desactiva el bicicletero cuando está vacío', async () => {
    prismaSimulado.bicicletero.findUnique.mockResolvedValue(bicicleteroBase);
    prismaSimulado.bicicleta.count.mockResolvedValue(0);
    prismaSimulado.bicicletero.update.mockResolvedValue({
      ...bicicleteroBase,
      activo: false
    } as Bicicletero);

    const resultado = await eliminarBicicletero('bic-1');

    expect(resultado.message).toContain('eliminado correctamente');
    expect(prismaSimulado.bicicletero.update).toHaveBeenCalledWith({
      where: { id: 'bic-1' },
      data: { activo: false }
    });
  });
});

describe('listarBicicleteros', () => {
  beforeEach(() => {
    prismaSimulado.bicicletero.findMany.mockResolvedValue([bicicleteroBase]);
    (prismaSimulado.bicicleta.groupBy as unknown as jest.Mock).mockResolvedValue([]);
    prismaSimulado.asignacionGuardia.findMany.mockResolvedValue([
      { bicicleteroId: 'bic-1', guardia: { id: 'g1', nombre: 'Pedro Soto' } }
    ] as never);
  });

  it.each([RolUsuario.GUARDIA, RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR])(
    'muestra a %s qué guardia gestiona cada bicicletero',
    async (rol) => {
      const [bicicletero] = await listarBicicleteros(rol);

      expect(bicicletero).toMatchObject({ guardiaActivo: { id: 'g1', nombre: 'Pedro Soto' } });
    }
  );

  it('a estudiantes y funcionarios no les muestra el guardia ni lo consulta', async () => {
    const [bicicletero] = await listarBicicleteros(RolUsuario.ESTUDIANTE);

    expect(bicicletero).not.toHaveProperty('guardiaActivo');
    expect(prismaSimulado.asignacionGuardia.findMany).not.toHaveBeenCalled();
  });

  it('un bicicletero sin guardia aparece sin guardia activo', async () => {
    prismaSimulado.asignacionGuardia.findMany.mockResolvedValue([]);

    const [bicicletero] = await listarBicicleteros(RolUsuario.ADMIN_CENTRAL);

    expect(bicicletero.guardiaActivo).toBeNull();
  });
});
