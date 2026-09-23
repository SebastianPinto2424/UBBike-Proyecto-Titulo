import '../helpers/env-setup';
import { prismaMock } from '../helpers/prisma-mock';

import { iniciarEntregas, solicitarEntregaInmediata } from '../../src/modulos/entregas/entrega.worker';

const esperarCiclo = () => new Promise<void>((resolver) => setImmediate(resolver));

const corridas = () => prismaMock.entregaPendiente.findMany.mock.calls.length;

describe('worker de entregas', () => {
  let detener: (() => Promise<void>) | null = null;

  beforeEach(() => {
    prismaMock.entregaPendiente.findMany.mockResolvedValue([] as never);
  });

  afterEach(async () => {
    if (detener) {
      await detener();
      detener = null;
    }
  });

  it('procesa la cola apenas arranca', async () => {
    detener = iniciarEntregas();
    await esperarCiclo();

    expect(corridas()).toBe(1);
  });

  it('despierta al instante en vez de esperar el ciclo de 5 segundos', async () => {
    detener = iniciarEntregas();
    await esperarCiclo();
    expect(corridas()).toBe(1);

    solicitarEntregaInmediata();
    await esperarCiclo();

    expect(corridas()).toBe(2);
  });

  it('no solapa corridas: varias solicitudes durante una corrida generan una sola mas', async () => {
    let liberar: (filas: never[]) => void = () => {};
    prismaMock.entregaPendiente.findMany.mockImplementationOnce(
      () => new Promise((resolver) => (liberar = resolver as never)) as never
    );

    detener = iniciarEntregas();
    await esperarCiclo();
    expect(corridas()).toBe(1);

    solicitarEntregaInmediata();
    solicitarEntregaInmediata();
    solicitarEntregaInmediata();
    await esperarCiclo();

    expect(corridas()).toBe(1);

    liberar([]);
    await esperarCiclo();
    await esperarCiclo();

    expect(corridas()).toBe(2);
  });

  it('deja de despertar despues de detenerse', async () => {
    const parar = iniciarEntregas();
    await esperarCiclo();
    await parar();
    const antes = corridas();

    solicitarEntregaInmediata();
    await esperarCiclo();

    expect(corridas()).toBe(antes);
  });
});
