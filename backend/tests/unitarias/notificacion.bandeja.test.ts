import '../apoyo/configurar-entorno';

jest.mock('../../src/tiempo-real/tiempo-real', () => ({
  EventosTiempoReal: { NOTIFICACION: 'notificacion' },
  emitirTiempoReal: jest.fn(),
  salaUsuario: (id: string) => `usuario:${id}`
}));

jest.mock('../../src/modulos/notificaciones/notificacion.repositorio', () => ({
  ejecutarEnTransaccion: jest.fn((callback: (db: unknown) => unknown) => callback({})),
  crear: jest.fn(),
  buscarIdsPorRoles: jest.fn(),
  listarDeUsuario: jest.fn(),
  contarNoLeidas: jest.fn(),
  buscarDeUsuario: jest.fn(),
  marcarLeida: jest.fn(),
  marcarTodasLeidas: jest.fn()
}));

jest.mock('../../src/modulos/notificaciones/dispositivo.repositorio', () => ({
  guardarToken: jest.fn().mockResolvedValue({}),
  eliminarToken: jest.fn().mockResolvedValue({}),
  eliminarTodosDeUsuario: jest.fn().mockResolvedValue({})
}));

jest.mock('../../src/modulos/entregas/entrega.repositorio', () => ({
  encolarEntrega: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/entregas/entrega.procesador', () => ({
  solicitarEntregaInmediata: jest.fn()
}));

import * as dispositivos from '../../src/modulos/notificaciones/dispositivo.repositorio';
import * as repositorio from '../../src/modulos/notificaciones/notificacion.repositorio';
import {
  eliminarDispositivo,
  listarNotificacionesUsuario,
  marcarNotificacionLeida,
  marcarTodasLeidas,
  notificarUsuariosPorRol,
  olvidarDispositivosDeUsuario,
  registrarDispositivo
} from '../../src/modulos/notificaciones/notificacion.servicio';
import { TipoNotificacion } from '../../src/modulos/notificaciones/tipo-notificacion';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';
import { emitirTiempoReal } from '../../src/tiempo-real/tiempo-real';

const repo = repositorio as jest.Mocked<typeof repositorio>;
const uuid = (n: number) => `00000000-0000-4000-8000-00000000000${n}`;

describe('bandeja de notificaciones', () => {
  it('pagina con cursor y cuenta las no leídas', async () => {
    repo.listarDeUsuario.mockResolvedValue([
      { id: uuid(1) },
      { id: uuid(2) },
      { id: uuid(3) }
    ] as never);
    repo.contarNoLeidas.mockResolvedValue(7);

    const resultado = await listarNotificacionesUsuario('u1', { limite: 2 });

    expect(repo.listarDeUsuario).toHaveBeenCalledWith(
      expect.objectContaining({ usuarioId: 'u1', take: 3, soloNoLeidas: false })
    );
    expect(resultado.notificaciones).toHaveLength(2);
    expect(resultado.nextCursor).toBe(uuid(2));
    expect(resultado.noLeidas).toBe(7);
  });

  it('la última página no tiene cursor', async () => {
    repo.listarDeUsuario.mockResolvedValue([{ id: uuid(1) }] as never);
    repo.contarNoLeidas.mockResolvedValue(0);

    const resultado = await listarNotificacionesUsuario('u1', {
      cursor: uuid(9),
      soloNoLeidas: true
    });

    expect(resultado.nextCursor).toBeNull();
    expect(repo.listarDeUsuario).toHaveBeenCalledWith(
      expect.objectContaining({ cursor: uuid(9), soloNoLeidas: true, take: 21 })
    );
  });

  it('rechaza cursores y límites inválidos', async () => {
    await expect(listarNotificacionesUsuario('u1', { cursor: 'abc' })).rejects.toMatchObject({
      statusCode: 400
    });
    await expect(listarNotificacionesUsuario('u1', { limite: -1 })).rejects.toMatchObject({
      statusCode: 400
    });
  });

  it('marcar como leída una ajena responde 404', async () => {
    repo.buscarDeUsuario.mockResolvedValue(null);

    await expect(marcarNotificacionLeida('u1', 'n9')).rejects.toMatchObject({ statusCode: 404 });
    expect(repo.marcarLeida).not.toHaveBeenCalled();
  });

  it('marcar como leída avisa a los otros dispositivos del usuario', async () => {
    repo.buscarDeUsuario.mockResolvedValue({ id: 'n1' } as never);
    repo.marcarLeida.mockResolvedValue({ id: 'n1', leida: true } as never);

    await expect(marcarNotificacionLeida('u1', 'n1')).resolves.toMatchObject({ leida: true });
    expect(emitirTiempoReal).toHaveBeenCalledWith(['usuario:u1'], 'notificacion', {
      accion: 'leida',
      notificacionId: 'n1'
    });
  });

  it('marcar todas como leídas', async () => {
    await expect(marcarTodasLeidas('u1')).resolves.toEqual({
      message: 'Notificaciones marcadas como leídas'
    });
    expect(emitirTiempoReal).toHaveBeenCalledWith(['usuario:u1'], 'notificacion', {
      accion: 'todas_leidas'
    });
  });
});

describe('avisos por rol y dispositivos', () => {
  it('notifica a cada usuario de los roles, excluyendo a quien actúa', async () => {
    repo.buscarIdsPorRoles.mockResolvedValue([{ id: 'a1' }, { id: 'a2' }] as never);
    repo.crear.mockImplementation((async (data: { usuarioId: string }) => ({
      id: `n-${data.usuarioId}`,
      ...data
    })) as never);

    await notificarUsuariosPorRol({
      roles: [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR],
      titulo: 'Nueva incidencia reportada',
      mensaje: 'Hay un reporte pendiente',
      tipo: TipoNotificacion.INCIDENCIA,
      excluirUsuarioId: 'u1'
    });

    expect(repo.buscarIdsPorRoles).toHaveBeenCalledWith(
      [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR],
      undefined,
      'u1'
    );
    expect(repo.crear).toHaveBeenCalledTimes(2);
  });

  it('registra, elimina y olvida los dispositivos push', async () => {
    await registrarDispositivo('u1', 'token-fcm', 'android');
    await eliminarDispositivo('u1', 'token-fcm');
    await olvidarDispositivosDeUsuario('u1');

    expect(dispositivos.guardarToken).toHaveBeenCalledWith('u1', 'token-fcm', 'android');
    expect(dispositivos.eliminarToken).toHaveBeenCalledWith('u1', 'token-fcm');
    expect(dispositivos.eliminarTodosDeUsuario).toHaveBeenCalledWith('u1');
  });
});
