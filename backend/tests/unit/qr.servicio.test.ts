import '../helpers/env-setup';
import '../helpers/prisma-mock';
import { prismaMock } from '../helpers/prisma-mock';

jest.mock('../../src/configuracion/redis', () => ({
  obtenerClienteRedis: jest.fn().mockResolvedValue(null)
}));

jest.mock('../../src/tiempo-real/tiempo-real', () => ({
  ...jest.requireActual('../../src/tiempo-real/tiempo-real'),
  emitirTiempoReal: jest.fn()
}));

import {
  consultarEstadoQr,
  generarQrTemporal,
  liberarQrTemporal,
  validarQrTemporal
} from '../../src/modulos/qr/qr.servicio';
import { emitirTiempoReal } from '../../src/tiempo-real/tiempo-real';

const emitirMock = emitirTiempoReal as jest.MockedFunction<typeof emitirTiempoReal>;

beforeEach(() => emitirMock.mockClear());

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

  it('avisa al dueño del QR cuando un validador lo escanea', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue(codigoQrBase as any);
    prismaMock.codigoQrTemporal.updateMany.mockResolvedValue({ count: 1 });

    await validarQrTemporal('UBBIKE-tokenValido', {
      validadorUsuarioId: 'admin-uuid-1',
      rol: 'ADMINISTRADOR'
    });

    expect(emitirMock).toHaveBeenCalledWith(['usuario:user-uuid-1'], 'qr', {
      qrId: 'qr-uuid-1',
      estado: 'ESCANEADO',
      tipo: 'INGRESO'
    });
  });

  it('no avisa si otro validador ya habia tomado el QR', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue(codigoQrBase as any);
    prismaMock.codigoQrTemporal.updateMany.mockResolvedValue({ count: 0 });

    await expect(
      validarQrTemporal('UBBIKE-tokenValido', {
        validadorUsuarioId: 'admin-uuid-1',
        rol: 'ADMINISTRADOR'
      })
    ).rejects.toMatchObject({ statusCode: 409 });
    expect(emitirMock).not.toHaveBeenCalled();
  });

  it('no avisa cuando se consulta sin validador', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue(codigoQrBase as any);

    await validarQrTemporal('UBBIKE-tokenValido');

    expect(emitirMock).not.toHaveBeenCalled();
  });
});

describe('liberarQrTemporal', () => {
  const contexto = { validadorUsuarioId: 'guardia-uuid-1', rol: 'GUARDIA' };

  it('avisa al dueño que el guardia soltó su QR para que pueda generar otro', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue({
      ...codigoQrBase,
      escaneadoPorGuardiaId: 'guardia-uuid-1'
    } as any);
    prismaMock.codigoQrTemporal.updateMany.mockResolvedValue({ count: 1 });

    await liberarQrTemporal('UBBIKE-tokenValido', contexto);

    expect(prismaMock.codigoQrTemporal.updateMany).toHaveBeenCalledWith({
      where: { id: 'qr-uuid-1', usado: false, escaneadoPorGuardiaId: 'guardia-uuid-1' },
      data: { escaneadoPorGuardiaId: null, escaneadoEn: null }
    });
    expect(emitirMock).toHaveBeenCalledWith(['usuario:user-uuid-1'], 'qr', {
      qrId: 'qr-uuid-1',
      estado: 'LIBERADO',
      tipo: 'INGRESO'
    });
  });

  it('no avisa si el QR no estaba tomado por ese guardia', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue(codigoQrBase as any);
    prismaMock.codigoQrTemporal.updateMany.mockResolvedValue({ count: 0 });

    await liberarQrTemporal('UBBIKE-tokenValido', contexto);

    expect(emitirMock).not.toHaveBeenCalled();
  });

  it('ignora un token que no existe', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue(null);

    await expect(liberarQrTemporal('token-no-existe', contexto)).resolves.toBeUndefined();
    expect(emitirMock).not.toHaveBeenCalled();
  });
});

describe('consultarEstadoQr', () => {
  it('indica que el QR sigue activo si nadie lo tiene tomado', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue(codigoQrBase as any);

    await expect(consultarEstadoQr('qr-uuid-1', 'user-uuid-1')).resolves.toMatchObject({
      estado: 'ACTIVO',
      tipo: 'INGRESO'
    });
  });

  it('indica que un guardia lo está revisando', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue({
      ...codigoQrBase,
      escaneadoPorGuardiaId: 'guardia-uuid-1',
      escaneadoEn: new Date()
    } as any);

    await expect(consultarEstadoQr('qr-uuid-1', 'user-uuid-1')).resolves.toMatchObject({
      estado: 'ESCANEADO'
    });
  });

  it('entrega el resultado del movimiento ya registrado con ese QR', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue({
      ...codigoQrBase,
      usado: true,
      escaneadoPorGuardiaId: 'guardia-uuid-1',
      escaneadoEn: new Date()
    } as any);
    prismaMock.movimiento.findFirst.mockResolvedValue({
      estado: 'DENEGADO',
      motivoDenegacion: 'La bicicleta no coincide'
    } as any);

    await expect(consultarEstadoQr('qr-uuid-1', 'user-uuid-1')).resolves.toMatchObject({
      estado: 'DENEGADO',
      motivo: 'La bicicleta no coincide'
    });
  });

  it('indica que fue reemplazado si se usó sin registrar movimiento', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue({
      ...codigoQrBase,
      usado: true
    } as any);

    await expect(consultarEstadoQr('qr-uuid-1', 'user-uuid-1')).resolves.toMatchObject({
      estado: 'REEMPLAZADO'
    });
  });

  it('no deja consultar el QR de otra persona', async () => {
    prismaMock.codigoQrTemporal.findFirst.mockResolvedValue(null);

    await expect(consultarEstadoQr('qr-uuid-1', 'otro-usuario')).rejects.toMatchObject({
      statusCode: 404
    });
  });
});
