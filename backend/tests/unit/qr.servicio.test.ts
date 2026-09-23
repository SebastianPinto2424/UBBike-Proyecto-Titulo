import '../helpers/env-setup';
import '../helpers/prisma-mock';
import { prismaMock } from '../helpers/prisma-mock';

jest.mock('../../src/configuracion/redis', () => ({
  obtenerClienteRedis: jest.fn().mockResolvedValue(null)
}));

import { generarQrTemporal, validarQrTemporal } from '../../src/modulos/qr/qr.servicio';

const bicicletaBase = {
  id: 'bici-uuid-1',
  usuarioId: 'user-uuid-1',
  descripcion: 'Bici roja',
  marca: null,
  modelo: null,
  color: 'rojo',
  aro: null,
  numeroSerie: null,
  fotoUrl: null,
  fotoNombreArchivo: null,
  fotoMimeType: null,
  fotoTamanoBytes: null,
  fotoActualizadaEn: null,
  activa: true,
  dentroBicicletero: false,
  bicicleteroActualId: null,
  creadoEn: new Date(),
  actualizadoEn: new Date(),
  eliminadoEn: null,
  bicicleteroActual: null,
  usuario: {
    id: 'user-uuid-1',
    nombre: 'Juan',
    correo: 'juan@alumnos.ubiobio.cl',
    rut: null
  }
};

const codigoQrBase = {
  id: 'qr-uuid-1',
  token: 'UBBIKE-tokenValido',
  usuarioId: 'user-uuid-1',
  bicicletaId: 'bici-uuid-1',
  bicicleteroId: null,
  tipo: 'INGRESO',
  expiraEn: new Date(Date.now() + 30_000),
  usado: false,
  escaneadoPorGuardiaId: null,
  escaneadoEn: null,
  creadoEn: new Date(),
  usuario: {
    id: 'user-uuid-1',
    nombre: 'Juan',
    correo: 'juan@alumnos.ubiobio.cl',
    rut: null
  },
  bicicleta: bicicletaBase,
  bicicletero: null
};

const bicicleteroBase = {
  id: 'bicicletero-uuid-1',
  activo: true,
  nombre: 'Bicicletero Central'
};

describe('generarQrTemporal', () => {
  it('lanza 404 si no existe bicicleta activa para el usuario', async () => {
    prismaMock.bicicleta.findFirst.mockResolvedValue(null);

    await expect(generarQrTemporal({ usuarioId: 'user-uuid-1' })).rejects.toMatchObject({
      statusCode: 404
    });
  });

  it('lanza 409 si bicicleta ya esta dentro y se pide INGRESO', async () => {
    prismaMock.bicicleta.findFirst.mockResolvedValue({
      ...bicicletaBase,
      dentroBicicletero: true,
      bicicleteroActualId: 'bicletero-uuid-1',
      bicicleteroActual: { id: 'bicicletero-uuid-1', nombre: 'Bicicletero Central' }
    } as any);

    await expect(
      generarQrTemporal({ usuarioId: 'user-uuid-1', tipo: 'INGRESO' as any })
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it('genera QR correctamente para bicicleta fuera del bicicletero', async () => {
    prismaMock.bicicleta.findFirst.mockResolvedValue(bicicletaBase as any);
    prismaMock.bicicletero.findUnique.mockResolvedValue({
      id: 'bicicletero-uuid-1',
      nombre: 'Centro Idiomas',
      activo: true
    } as any);
    prismaMock.codigoQrTemporal.updateMany.mockResolvedValue({ count: 0 });
    prismaMock.codigoQrTemporal.create.mockResolvedValue({
      ...codigoQrBase,
      token: 'UBBIKE-nuevoToken'
    } as any);

    const resultado = await generarQrTemporal({
      usuarioId: 'user-uuid-1',
      bicicleteroId: 'bicicletero-uuid-1'
    });

    expect(resultado.token).toMatch(/^UBBIKE-/);
    expect(resultado.tipo).toBe('INGRESO');
    expect(resultado.duracionSegundos).toBe(15);
  });

  it('genera QR correctamente para retiro cuando la bicicleta esta dentro', async () => {
    prismaMock.bicicleta.findFirst.mockResolvedValue({
      ...bicicletaBase,
      dentroBicicletero: true,
      bicicleteroActualId: bicicleteroBase.id,
      bicicleteroActual: bicicleteroBase
    } as any);
    prismaMock.codigoQrTemporal.updateMany.mockResolvedValue({ count: 0 });
    prismaMock.codigoQrTemporal.create.mockResolvedValue({
      ...codigoQrBase,
      token: 'UBBIKE-retiroToken',
      tipo: 'RETIRO',
      bicicleteroId: bicicleteroBase.id
    } as any);

    const resultado = await generarQrTemporal({
      usuarioId: 'user-uuid-1'
    });

    expect(resultado.token).toMatch(/^UBBIKE-/);
    expect(resultado.tipo).toBe('RETIRO');
    expect(resultado.bicicletero).toEqual({
      id: bicicleteroBase.id,
      nombre: bicicleteroBase.nombre
    });
    expect(resultado.duracionSegundos).toBe(15);
  });
});

describe('validarQrTemporal', () => {
  it('lanza 404 si el token no existe', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue(null);

    await expect(validarQrTemporal('token-no-existe')).rejects.toMatchObject({ statusCode: 404 });
  });

  it('lanza 409 si el QR ya fue usado', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue({
      ...codigoQrBase,
      usado: true
    } as any);

    await expect(validarQrTemporal('UBBIKE-tokenValido')).rejects.toMatchObject({
      statusCode: 409
    });
  });

  it('lanza 410 si el QR esta expirado', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue({
      ...codigoQrBase,
      expiraEn: new Date(Date.now() - 1000)
    } as any);

    await expect(validarQrTemporal('UBBIKE-tokenValido')).rejects.toMatchObject({
      statusCode: 410
    });
  });

  it('devuelve datos del usuario para QR valido', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue(codigoQrBase as any);

    const resultado = await validarQrTemporal('UBBIKE-tokenValido');

    expect(resultado.valido).toBe(true);
    expect(resultado.usuario.id).toBe('user-uuid-1');
    expect(resultado.tipo).toBe('INGRESO');
  });

  it('devuelve datos del usuario para QR valido de retiro', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue({
      ...codigoQrBase,
      tipo: 'RETIRO',
      bicicleteroId: bicicleteroBase.id,
      bicicleta: {
        ...bicicletaBase,
        dentroBicicletero: true,
        bicicleteroActualId: bicicleteroBase.id,
        bicicleteroActual: bicicleteroBase
      },
      bicicletero: bicicleteroBase
    } as any);

    const resultado = await validarQrTemporal('UBBIKE-tokenValido');

    expect(resultado.valido).toBe(true);
    expect(resultado.usuario.id).toBe('user-uuid-1');
    expect(resultado.tipo).toBe('RETIRO');
    expect(resultado.bicicletero).toEqual({
      id: bicicleteroBase.id,
      nombre: bicicleteroBase.nombre
    });
  });
});
