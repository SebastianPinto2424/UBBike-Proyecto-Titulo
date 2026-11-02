import '../apoyo/configurar-entorno';
import { prismaSimulado } from '../apoyo/prisma-simulado';
const mockIo = {
  use: jest.fn(),
  on: jest.fn(),
  to: jest.fn().mockReturnValue({ emit: jest.fn() })
};
jest.mock('socket.io', () => ({ Server: jest.fn().mockImplementation(() => mockIo) }));
import { inicializarTiempoReal, emitirTiempoReal } from '../../src/tiempo-real/tiempo-real';
import type { Server } from 'http';

beforeEach(() => {
  jest.useFakeTimers();
});
afterEach(() => {
  jest.clearAllTimers();
  jest.useRealTimers();
});
const conectar = () => {
  inicializarTiempoReal({} as Server);
  const desconectar = jest.fn();
  const socket = {
    data: {
      usuarioId: 'u',
      rol: 'GUARDIA',
      versionSesion: 1,
      exp: Math.floor(Date.now() / 1000) + 1200
    },
    join: jest.fn(),
    disconnect: desconectar,
    on: jest.fn()
  };
  mockIo.on.mock.calls.find(([e]) => e === 'connection')![1](socket);
  return socket;
};
it('desconecta al vencer JWT aunque la versión siga vigente', async () => {
  prismaSimulado.usuario.findUnique.mockResolvedValue({
    cuentaActiva: true,
    correoVerificado: true,
    versionSesion: 1
  } as never);
  const socket = conectar();
  await jest.advanceTimersByTimeAsync(1200000);
  expect(socket.disconnect).toHaveBeenCalledWith(true);
});
it('un fallo de base de datos durante la revalidación no queda sin capturar', async () => {
  prismaSimulado.usuario.findUnique.mockRejectedValue(new Error('DB sin conexión'));
  const log = jest.spyOn(console, 'error').mockImplementation(() => {});
  try {
    const socket = conectar();
    await jest.advanceTimersByTimeAsync(300000);
    expect(socket.disconnect).toHaveBeenCalled();
  } finally {
    log.mockRestore();
  }
});
it('libera ambos temporizadores cuando se desconecta', () => {
  const socket = conectar();
  socket.on.mock.calls.find(([e]) => e === 'disconnect')![1]();
  expect(jest.getTimerCount()).toBe(0);
});
it('deduplica salas al emitir', () => {
  inicializarTiempoReal({} as Server);
  emitirTiempoReal(['u', 'u'], 'incidencia');
  expect(mockIo.to).toHaveBeenCalledWith(['u']);
});

it('el tiempo real rechaza conexiones de navegadores de otros sitios', () => {
  const { Server: ServidorSocket } = jest.requireMock('socket.io') as { Server: jest.Mock };
  inicializarTiempoReal({} as Server);
  const opciones = ServidorSocket.mock.calls.at(-1)![1] as {
    allowRequest: (
      solicitud: { headers: Record<string, string | undefined> },
      callback: (error: string | null, permitido: boolean) => void
    ) => void;
  };
  const respuesta = (origen?: string) => {
    let permitido = false;
    opciones.allowRequest({ headers: { origin: origen, host: 'ubbike.ejemplo.cl' } }, (_e, ok) => {
      permitido = ok;
    });
    return permitido;
  };

  expect(respuesta(undefined)).toBe(true);
  expect(respuesta('https://ubbike.ejemplo.cl')).toBe(true);
  expect(respuesta('https://sitio-ajeno.com')).toBe(false);
});
