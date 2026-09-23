import '../helpers/env-setup';
import { prismaMock } from '../helpers/prisma-mock';

jest.mock('../../src/tiempo-real/tiempo-real', () => ({
  EventosTiempoReal: { NOTIFICACION: 'notificacion' },
  emitirTiempoReal: jest.fn(),
  salaUsuario: (id: string) => `usuario:${id}`
}));

jest.mock('../../src/modulos/notificaciones/push.servicio', () => ({
  enviarPushAUsuario: jest.fn().mockResolvedValue(undefined)
}));

import {
  crearNotificacion,
  ejecutarEfectosDiferidos,
  type EfectosDiferidos
} from '../../src/modulos/notificaciones/notificacion.servicio';
import { TipoNotificacion } from '../../src/modulos/notificaciones/tipo-notificacion';
import { emitirTiempoReal } from '../../src/tiempo-real/tiempo-real';
import { enviarPushAUsuario } from '../../src/modulos/notificaciones/push.servicio';

const datosNotificacion = {
  usuarioId: 'user-1',
  titulo: 'Nueva incidencia reportada',
  mensaje: 'Hay un reporte pendiente',
  tipo: TipoNotificacion.INCIDENCIA
};

describe('crearNotificacion con efectos diferidos', () => {
  beforeEach(() => {
    prismaMock.notificacion.create.mockResolvedValue({ id: 'notif-1' } as never);
  });

  it('encola push durable y emite tiempo real si no se difieren efectos', async () => {
    await crearNotificacion(datosNotificacion);

    expect(emitirTiempoReal).toHaveBeenCalledTimes(1);
    expect(enviarPushAUsuario).not.toHaveBeenCalled();
    expect(prismaMock.entregaPendiente.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ tipo: 'PUSH' })
    });
  });

  it('no entrega nada mientras los efectos siguen pendientes', async () => {
    const efectos: EfectosDiferidos = [];

    await crearNotificacion(datosNotificacion, undefined, efectos);

    expect(prismaMock.notificacion.create).toHaveBeenCalled();
    expect(emitirTiempoReal).not.toHaveBeenCalled();
    expect(enviarPushAUsuario).not.toHaveBeenCalled();
    expect(efectos).toHaveLength(1);
  });

  it('emite tiempo real al ejecutar efectos; el worker es responsable del push', async () => {
    const efectos: EfectosDiferidos = [];

    await crearNotificacion(datosNotificacion, undefined, efectos);
    ejecutarEfectosDiferidos(efectos);

    expect(emitirTiempoReal).toHaveBeenCalledTimes(1);
    expect(enviarPushAUsuario).not.toHaveBeenCalled();
    expect(prismaMock.entregaPendiente.create).toHaveBeenCalledTimes(1);
  });

  it('no envia push para tipos que no son visibles en la app', async () => {
    const efectos: EfectosDiferidos = [];

    await crearNotificacion(
      { ...datosNotificacion, tipo: TipoNotificacion.SISTEMA },
      undefined,
      efectos
    );
    ejecutarEfectosDiferidos(efectos);

    expect(emitirTiempoReal).toHaveBeenCalledTimes(1);
    expect(enviarPushAUsuario).not.toHaveBeenCalled();
    expect(prismaMock.entregaPendiente.create).not.toHaveBeenCalled();
  });
});
