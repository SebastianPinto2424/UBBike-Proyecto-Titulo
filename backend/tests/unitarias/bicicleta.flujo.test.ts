import '../apoyo/configurar-entorno';
import { prismaSimulado } from '../apoyo/prisma-simulado';

jest.mock('../../src/modulos/bicicletas/foto-bicicleta.servicio', () => ({
  guardarFotoBicicleta: jest.fn(),
  eliminarArchivoFotoBicicleta: jest.fn().mockResolvedValue(undefined)
}));

import {
  activarBicicleta,
  actualizarBicicleta,
  crearBicicleta,
  desactivarBicicleta,
  eliminarBicicleta,
  listarBicicletasUsuario,
  obtenerBicicletaActivaUsuario
} from '../../src/modulos/bicicletas/bicicleta.servicio';
import {
  eliminarArchivoFotoBicicleta,
  guardarFotoBicicleta
} from '../../src/modulos/bicicletas/foto-bicicleta.servicio';

const fotoGuardada = {
  fotoUrl: '/uploads/bicicletas/b1.jpg',
  fotoNombreArchivo: 'b1.jpg',
  fotoMimeType: 'image/jpeg',
  fotoTamanoBytes: 2048,
  fotoActualizadaEn: new Date('2026-10-20T10:00:00Z')
};

const crearBici = (cambios: Record<string, unknown> = {}) =>
  ({
    id: 'b1',
    usuarioId: 'u1',
    descripcion: 'Urbana azul',
    marca: 'Oxford',
    modelo: 'Venus',
    color: 'Azul',
    aro: '26',
    numeroSerie: 'SN-1',
    fotoUrl: null,
    fotoNombreArchivo: null,
    fotoMimeType: null,
    fotoTamanoBytes: null,
    fotoActualizadaEn: null,
    activa: true,
    dentroBicicletero: false,
    bicicleteroActualId: null,
    bicicleteroActual: null,
    creadoEn: new Date(),
    actualizadoEn: new Date(),
    eliminadoEn: null,
    ...cambios
  }) as never;

const datosActualizados = () =>
  (prismaSimulado.bicicleta.update.mock.calls.at(-1)?.[0] as { data: Record<string, unknown> })
    .data;

beforeEach(() => {
  prismaSimulado.bicicleta.update.mockImplementation((async (args: { data: object }) =>
    crearBici(args.data as Record<string, unknown>)) as never);
});

describe('consultas de bicicletas', () => {
  it('lista las bicicletas del usuario con su bicicletero actual', async () => {
    prismaSimulado.bicicleta.findMany.mockResolvedValue([
      crearBici({
        dentroBicicletero: true,
        bicicleteroActual: { id: 'r1', nombre: 'Biblioteca', capacidad: 20 }
      })
    ]);

    const [bici] = await listarBicicletasUsuario('u1');

    expect(bici.bicicleteroActual).toEqual({ id: 'r1', nombre: 'Biblioteca' });
    expect(bici).not.toHaveProperty('usuarioId');
  });

  it('entrega null si no tiene bicicleta activa', async () => {
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(null);

    await expect(obtenerBicicletaActivaUsuario('u1')).resolves.toBeNull();
  });

  it('entrega la bicicleta activa', async () => {
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(crearBici());

    await expect(obtenerBicicletaActivaUsuario('u1')).resolves.toMatchObject({
      id: 'b1',
      activa: true
    });
  });
});

describe('crearBicicleta', () => {
  it('la primera bicicleta queda activa y guarda la foto nueva', async () => {
    (guardarFotoBicicleta as jest.Mock).mockResolvedValue(fotoGuardada);
    prismaSimulado.bicicleta.count.mockResolvedValue(0);
    prismaSimulado.bicicleta.create.mockResolvedValue(crearBici({ activa: false }));
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(crearBici(fotoGuardada));

    const bici = await crearBicicleta({
      usuarioId: 'u1',
      descripcion: 'Urbana azul',
      marca: '',
      fotoUrl: 'data:image/jpeg;base64,AAAA'
    });

    expect(guardarFotoBicicleta).toHaveBeenCalledWith('bicicleta', 'data:image/jpeg;base64,AAAA');
    expect(prismaSimulado.bicicleta.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        marca: null,
        fotoNombreArchivo: 'b1.jpg',
        activa: false
      })
    });
    expect(prismaSimulado.bicicleta.updateMany).toHaveBeenCalled();
    expect(bici.fotoUrl).toBe('/uploads/bicicletas/b1.jpg');
  });

  it('una bicicleta adicional sin activar no cambia la activa', async () => {
    prismaSimulado.bicicleta.count.mockResolvedValue(2);
    prismaSimulado.bicicleta.create.mockResolvedValue(crearBici({ id: 'b2', activa: false }));
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(crearBici({ id: 'b2', activa: false }));

    await crearBicicleta({ usuarioId: 'u1', descripcion: 'Segunda', fotoUrl: '/uploads/x.jpg' });

    expect(guardarFotoBicicleta).not.toHaveBeenCalled();
    expect(prismaSimulado.bicicleta.updateMany).not.toHaveBeenCalled();
    expect(prismaSimulado.bicicleta.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ fotoUrl: null })
    });
  });
});

describe('actualizarBicicleta', () => {
  it('responde 404 si la bicicleta no es del usuario', async () => {
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(null);

    await expect(actualizarBicicleta('u1', 'b9', { descripcion: 'x' })).rejects.toMatchObject({
      statusCode: 404
    });
  });

  it('actualiza solo los campos enviados y limpia los vacios', async () => {
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(crearBici());

    await actualizarBicicleta('u1', 'b1', {
      descripcion: 'Montaña',
      marca: '',
      modelo: null,
      color: 'Rojo',
      aro: '',
      numeroSerie: ''
    });

    expect(datosActualizados()).toMatchObject({
      descripcion: 'Montaña',
      marca: null,
      modelo: null,
      color: 'Rojo',
      aro: null,
      numeroSerie: null
    });
    expect(eliminarArchivoFotoBicicleta).not.toHaveBeenCalled();
  });

  it('quitar la foto borra el archivo y sus metadatos', async () => {
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(crearBici(fotoGuardada));

    await actualizarBicicleta('u1', 'b1', { fotoUrl: null });

    expect(eliminarArchivoFotoBicicleta).toHaveBeenCalledWith('b1.jpg');
    expect(datosActualizados()).toMatchObject({
      fotoUrl: null,
      fotoNombreArchivo: null,
      fotoTamanoBytes: null
    });
  });

  it('una foto nueva reemplaza el archivo anterior', async () => {
    (guardarFotoBicicleta as jest.Mock).mockResolvedValue({
      ...fotoGuardada,
      fotoNombreArchivo: 'b1-nueva.jpg'
    });
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(crearBici(fotoGuardada));

    await actualizarBicicleta('u1', 'b1', { fotoUrl: 'data:image/png;base64,BBBB' });

    expect(guardarFotoBicicleta).toHaveBeenCalledWith('b1', 'data:image/png;base64,BBBB');
    expect(eliminarArchivoFotoBicicleta).toHaveBeenCalledWith('b1.jpg');
    expect(datosActualizados()).toMatchObject({ fotoNombreArchivo: 'b1-nueva.jpg' });
  });

  it('mantener la URL actual no toca la foto', async () => {
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(crearBici(fotoGuardada));

    await actualizarBicicleta('u1', 'b1', { fotoUrl: '/uploads/bicicletas/b1.jpg' });

    expect(guardarFotoBicicleta).not.toHaveBeenCalled();
    expect(eliminarArchivoFotoBicicleta).not.toHaveBeenCalled();
  });
});

describe('eliminarBicicleta', () => {
  it('no permite eliminar una bicicleta dentro de un bicicletero', async () => {
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(crearBici({ dentroBicicletero: true }));

    await expect(eliminarBicicleta('u1', 'b1')).rejects.toMatchObject({ statusCode: 409 });
    expect(prismaSimulado.bicicleta.updateMany).not.toHaveBeenCalled();
  });

  it('detecta si la bicicleta cambio de estado mientras se eliminaba', async () => {
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(crearBici());
    prismaSimulado.bicicleta.updateMany.mockResolvedValue({ count: 0 });

    await expect(eliminarBicicleta('u1', 'b1')).rejects.toMatchObject({ statusCode: 409 });
    expect(eliminarArchivoFotoBicicleta).not.toHaveBeenCalled();
  });

  it('al eliminar la activa, activa la siguiente disponible', async () => {
    prismaSimulado.bicicleta.findFirst
      .mockResolvedValueOnce(crearBici(fotoGuardada))
      .mockResolvedValueOnce(crearBici({ id: 'b2', activa: false }))
      .mockResolvedValueOnce(crearBici({ id: 'b2', activa: false }));
    prismaSimulado.bicicleta.updateMany.mockResolvedValue({ count: 1 });

    await expect(eliminarBicicleta('u1', 'b1')).resolves.toEqual({
      message: 'Bicicleta eliminada correctamente'
    });

    expect(prismaSimulado.bicicleta.updateMany).toHaveBeenCalledWith({
      where: { id: 'b1', usuarioId: 'u1', eliminadoEn: null, dentroBicicletero: false },
      data: { eliminadoEn: expect.any(Date), activa: false }
    });
    expect(eliminarArchivoFotoBicicleta).toHaveBeenCalledWith('b1.jpg');
    expect(prismaSimulado.bicicleta.update).toHaveBeenCalledWith({
      where: { id: 'b2' },
      data: { activa: true }
    });
  });

  it('al eliminar una inactiva no cambia la activa', async () => {
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(crearBici({ activa: false }));
    prismaSimulado.bicicleta.updateMany.mockResolvedValue({ count: 1 });

    await eliminarBicicleta('u1', 'b1');

    expect(prismaSimulado.bicicleta.update).not.toHaveBeenCalled();
  });
});

describe('activar y desactivar', () => {
  it('activar deja solo esa bicicleta activa', async () => {
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(crearBici({ activa: false }));

    await activarBicicleta('u1', 'b1');

    expect(prismaSimulado.bicicleta.updateMany).toHaveBeenCalledWith({
      where: { usuarioId: 'u1', eliminadoEn: null },
      data: { activa: false }
    });
    expect(prismaSimulado.bicicleta.update).toHaveBeenCalledWith({
      where: { id: 'b1' },
      data: { activa: true }
    });
  });

  it('activar una bicicleta ajena responde 404', async () => {
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(null);

    await expect(activarBicicleta('u1', 'b9')).rejects.toMatchObject({ statusCode: 404 });
  });

  it('desactivar guarda la bicicleta inactiva', async () => {
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(crearBici());

    const bici = await desactivarBicicleta('u1', 'b1');

    expect(datosActualizados()).toEqual({ activa: false });
    expect(bici.activa).toBe(false);
  });
});
