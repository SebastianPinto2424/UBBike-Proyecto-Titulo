import '../helpers/env-setup';
import { prismaMock } from '../helpers/prisma-mock';
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
  prismaMock.usuario.findUnique.mockResolvedValue({
    cuentaActiva: true,
    correoVerificado: true,
    versionSesion: 1
  } as never);
  const socket = conectar();
  await jest.advanceTimersByTimeAsync(1200000);
  expect(socket.disconnect).toHaveBeenCalledWith(true);
});
it('un fallo de base de datos durante la revalidación no queda sin capturar', async () => {
  prismaMock.usuario.findUnique.mockRejectedValue(new Error('DB sin conexión'));
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
