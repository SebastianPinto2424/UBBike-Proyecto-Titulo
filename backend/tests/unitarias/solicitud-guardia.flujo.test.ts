import '../apoyo/configurar-entorno';

jest.mock('../../src/modulos/acceso/solicitudes/solicitud-guardia.repositorio', () => ({
  ejecutarEnTransaccion: jest.fn((callback: (db: unknown) => unknown) => callback({})),
  buscarBicicletero: jest.fn(),
  buscarSolicitudAbierta: jest.fn(),
  buscarAsignacionActivaConGuardia: jest.fn(),
  crear: jest.fn(),
  buscarPorId: jest.fn(),
  buscarPorIdOError: jest.fn(),
  actualizar: jest.fn(),
  listar: jest.fn()
}));

jest.mock('../../src/comun/utilidades/bloqueos', () => ({
  bloquearClave: jest.fn().mockResolvedValue(undefined),
  bloquearFila: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/notificaciones/notificacion.servicio', () => ({
  crearNotificacion: jest.fn().mockResolvedValue(undefined),
  notificarUsuariosPorRol: jest.fn().mockResolvedValue(undefined),
  ejecutarEfectosDiferidos: jest.fn()
}));

jest.mock('../../src/modulos/auditoria/auditoria.servicio', () => ({
  registrarAuditoria: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/tiempo-real/tiempo-real', () => ({
  EventosTiempoReal: { SOLICITUD: 'solicitud' },
  emitirTiempoReal: jest.fn(),
  salaRol: (rol: string) => `rol:${rol}`,
  salaUsuario: (usuarioId: string) => `usuario:${usuarioId}`
}));

import * as repositorio from '../../src/modulos/acceso/solicitudes/solicitud-guardia.repositorio';
import {
  actualizarEstadoSolicitudGuardia,
  cancelarSolicitudGuardia
} from '../../src/modulos/acceso/solicitudes/seguimiento-solicitud.servicio';
import { mapearSolicitudGuardia } from '../../src/modulos/acceso/solicitudes/solicitud-guardia.mapeador';
import {
  crearSolicitudGuardia,
  listarSolicitudesGuardia,
  notificarGuardiaSolicitud
} from '../../src/modulos/acceso/solicitudes/solicitud-guardia.servicio';
import { EstadoSolicitudGuardia } from '../../src/modulos/acceso/solicitudes/estado-solicitud-guardia';
import { TipoSolicitudGuardia } from '../../src/modulos/acceso/solicitudes/tipo-solicitud-guardia';
import { registrarAuditoria } from '../../src/modulos/auditoria/auditoria.servicio';
import {
  crearNotificacion,
  ejecutarEfectosDiferidos,
  notificarUsuariosPorRol
} from '../../src/modulos/notificaciones/notificacion.servicio';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';
import { emitirTiempoReal } from '../../src/tiempo-real/tiempo-real';

const repo = repositorio as jest.Mocked<typeof repositorio>;
const tipo = Object.values(TipoSolicitudGuardia)[0] as TipoSolicitudGuardia;

const solicitante = {
  id: 'u1',
  nombre: 'Ana Rojas',
  correo: 'ana@alumnos.ubiobio.cl',
  rut: null,
  rol: RolUsuario.ESTUDIANTE
};
const guardia = {
  id: 'g1',
  nombre: 'Pedro Soto',
  correo: 'guardia@ubiobio.cl',
  rut: null,
  rol: RolUsuario.GUARDIA
};
const bicicletero = { id: 'r1', nombre: 'Biblioteca', ubicacion: 'Campus', activo: true };

const hace = (segundos: number) => new Date(Date.now() - segundos * 1000);

const crearSolicitud = (cambios: Record<string, unknown> = {}) =>
  ({
    id: 's1',
    tipo,
    estado: EstadoSolicitudGuardia.NOTIFICADA,
    mensaje: null,
    creadaEn: hace(120),
    notificadaGuardiaEn: hace(120),
    ultimaNotificacionUsuarioEn: hace(120),
    notificacionesGuardia: 1,
    respondidaPorGuardiaEn: null,
    enCaminoEn: null,
    resueltaEn: null,
    motivoCierre: null,
    cerradaPorUsuarioId: null,
    solicitadaPorUsuario: solicitante,
    guardiaAsignado: guardia,
    bicicletero,
    ...cambios
  }) as never;

beforeEach(() => {
  repo.ejecutarEnTransaccion.mockImplementation(((callback: (db: unknown) => unknown) =>
    callback({})) as never);
  repo.actualizar.mockImplementation((async (_id: string, data: Record<string, unknown>) =>
    crearSolicitud({
      estado: (data.estado as string) ?? EstadoSolicitudGuardia.NOTIFICADA
    })) as never);
});

describe('crearSolicitudGuardia', () => {
  it('responde 404 si el bicicletero no existe', async () => {
    repo.buscarBicicletero.mockResolvedValue(null);

    await expect(
      crearSolicitudGuardia({ usuarioId: 'u1', bicicleteroId: 'r1', tipo })
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it('responde 409 si el bicicletero esta inactivo', async () => {
    repo.buscarBicicletero.mockResolvedValue({ ...bicicletero, activo: false } as never);

    await expect(
      crearSolicitudGuardia({ usuarioId: 'u1', bicicleteroId: 'r1', tipo })
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it('con guardia asignado queda notificada y avisa al guardia y a central', async () => {
    repo.buscarBicicletero.mockResolvedValue(bicicletero as never);
    repo.buscarSolicitudAbierta.mockResolvedValue(null);
    repo.buscarAsignacionActivaConGuardia.mockResolvedValue({ guardia } as never);
    repo.crear.mockResolvedValue(crearSolicitud({ creadaEn: new Date() }));
    repo.buscarPorIdOError.mockResolvedValue(
      crearSolicitud({ creadaEn: new Date(), notificadaGuardiaEn: new Date() })
    );

    const resultado = await crearSolicitudGuardia({
      usuarioId: 'u1',
      bicicleteroId: 'r1',
      tipo,
      mensaje: 'Mi candado no abre'
    });

    expect(repo.crear).toHaveBeenCalledWith(
      expect.objectContaining({
        guardiaAsignadoId: 'g1',
        estado: EstadoSolicitudGuardia.NOTIFICADA,
        notificacionesGuardia: 1,
        mensaje: 'Mi candado no abre'
      }),
      {}
    );
    expect(crearNotificacion).toHaveBeenCalledWith(
      expect.objectContaining({ usuarioId: 'g1', titulo: 'Solicitud de apoyo' }),
      {},
      expect.any(Array)
    );
    expect(notificarUsuariosPorRol).toHaveBeenCalledWith(
      expect.objectContaining({ titulo: 'Nueva solicitud de atención', excluirUsuarioId: 'u1' }),
      {},
      expect.any(Array)
    );
    expect(registrarAuditoria).toHaveBeenCalledWith(
      expect.objectContaining({ accion: 'SOLICITUD_GUARDIA_CREADA' }),
      {}
    );
    expect(ejecutarEfectosDiferidos).toHaveBeenCalled();
    expect(emitirTiempoReal).toHaveBeenCalledWith(
      expect.arrayContaining(['usuario:u1', 'rol:GUARDIA']),
      'solicitud'
    );
    expect(resultado.puedeNotificarGuardia).toBe(false);
    expect(resultado.guardiasAsignados).toHaveLength(1);
  });

  it('sin guardia asignado queda pendiente y solo avisa a central', async () => {
    repo.buscarBicicletero.mockResolvedValue(bicicletero as never);
    repo.buscarSolicitudAbierta.mockResolvedValue(null);
    repo.buscarAsignacionActivaConGuardia.mockResolvedValue(null);
    repo.crear.mockResolvedValue(
      crearSolicitud({ estado: EstadoSolicitudGuardia.PENDIENTE, guardiaAsignado: null })
    );
    repo.buscarPorIdOError.mockResolvedValue(
      crearSolicitud({ estado: EstadoSolicitudGuardia.PENDIENTE, guardiaAsignado: null })
    );

    const resultado = await crearSolicitudGuardia({ usuarioId: 'u1', bicicleteroId: 'r1', tipo });

    expect(repo.crear).toHaveBeenCalledWith(
      expect.objectContaining({
        guardiaAsignadoId: null,
        estado: EstadoSolicitudGuardia.PENDIENTE,
        notificacionesGuardia: 0,
        mensaje: null
      }),
      {}
    );
    expect(crearNotificacion).not.toHaveBeenCalled();
    expect(notificarUsuariosPorRol).toHaveBeenCalled();
    expect(resultado.guardiaAsignado).toBeNull();
    expect(resultado.guardiasAsignados).toEqual([]);
  });

  it('si ya hay una solicitud abierta la reitera en vez de duplicarla', async () => {
    repo.buscarBicicletero.mockResolvedValue(bicicletero as never);
    repo.buscarSolicitudAbierta.mockResolvedValue({ id: 's1' } as never);
    repo.buscarPorId.mockResolvedValue(crearSolicitud());

    await crearSolicitudGuardia({ usuarioId: 'u1', bicicleteroId: 'r1', tipo });

    expect(repo.crear).not.toHaveBeenCalled();
    expect(repo.actualizar).toHaveBeenCalledWith(
      's1',
      expect.objectContaining({ notificacionesGuardia: { increment: 1 } }),
      {}
    );
    expect(crearNotificacion).toHaveBeenCalledWith(
      expect.objectContaining({ usuarioId: 'g1', titulo: 'Recordatorio de solicitud' }),
      {},
      expect.any(Array)
    );
  });

  it('no deja reiterar antes de un minuto', async () => {
    repo.buscarBicicletero.mockResolvedValue(bicicletero as never);
    repo.buscarSolicitudAbierta.mockResolvedValue({ id: 's1' } as never);
    repo.buscarPorId.mockResolvedValue(crearSolicitud({ notificadaGuardiaEn: hace(10) }));

    await expect(
      crearSolicitudGuardia({ usuarioId: 'u1', bicicleteroId: 'r1', tipo })
    ).rejects.toMatchObject({ statusCode: 409 });
    expect(repo.actualizar).not.toHaveBeenCalled();
  });

  it('el guardia no pide atencion en el bicicletero que gestiona', async () => {
    repo.buscarBicicletero.mockResolvedValue(bicicletero as never);
    repo.buscarSolicitudAbierta.mockResolvedValue(null);
    repo.buscarAsignacionActivaConGuardia.mockResolvedValue({ guardia } as never);

    await expect(
      crearSolicitudGuardia({ usuarioId: 'g1', bicicleteroId: 'r1', tipo })
    ).rejects.toMatchObject({
      statusCode: 403,
      message:
        'No puedes pedir atención en el bicicletero que gestionas. Si necesitas apoyo, avisa a central.'
    });
    expect(repo.crear).not.toHaveBeenCalled();
    expect(crearNotificacion).not.toHaveBeenCalled();
  });
});

describe('listarSolicitudesGuardia', () => {
  beforeEach(() => {
    repo.listar.mockResolvedValue([crearSolicitud()]);
  });

  it('cada rol ve solo lo que le corresponde', async () => {
    await listarSolicitudesGuardia({ usuarioId: 'g1', rol: RolUsuario.GUARDIA });
    expect(repo.listar).toHaveBeenLastCalledWith({
      where: { AND: [{ guardiaAsignadoId: 'g1' }] },
      limite: undefined
    });

    await listarSolicitudesGuardia({ usuarioId: 'u1', rol: RolUsuario.FUNCIONARIO });
    expect(repo.listar).toHaveBeenLastCalledWith({
      where: { AND: [{ solicitadaPorUsuarioId: 'u1' }] },
      limite: undefined
    });

    await listarSolicitudesGuardia({ usuarioId: 'a1', rol: RolUsuario.ADMIN_CENTRAL });
    expect(repo.listar).toHaveBeenLastCalledWith({ where: {}, limite: undefined });
  });

  it('el alcance propio muestra al personal solo las solicitudes que hizo', async () => {
    for (const [usuarioId, rol] of [
      ['g1', RolUsuario.GUARDIA],
      ['a1', RolUsuario.ADMIN_CENTRAL],
      ['a2', RolUsuario.ADMINISTRADOR]
    ]) {
      await listarSolicitudesGuardia({ usuarioId, rol, alcance: 'PROPIO' });
      expect(repo.listar).toHaveBeenLastCalledWith({
        where: { AND: [{ solicitadaPorUsuarioId: usuarioId }] },
        limite: undefined
      });
    }
  });

  it('filtra por estado, busca por texto y acota el limite', async () => {
    const resultado = await listarSolicitudesGuardia({
      usuarioId: 'a1',
      rol: RolUsuario.ADMINISTRADOR,
      estado: EstadoSolicitudGuardia.NOTIFICADA,
      q: '  biblioteca ',
      limite: 9000
    });

    const llamada = repo.listar.mock.calls[0][0];
    const condiciones = (llamada.where as { AND: Record<string, unknown>[] }).AND;
    expect(condiciones[0]).toEqual({ estado: EstadoSolicitudGuardia.NOTIFICADA });
    expect((condiciones[1].OR as unknown[]).length).toBe(8);
    expect(llamada.limite).toBe(500);
    expect(resultado[0].puedeNotificarGuardia).toBe(true);
    expect(resultado[0].segundosParaNotificarGuardia).toBe(0);
  });

  it('ignora el estado TODOS', async () => {
    await listarSolicitudesGuardia({
      usuarioId: 'a1',
      rol: RolUsuario.ADMINISTRADOR,
      estado: 'TODOS'
    });

    expect(repo.listar).toHaveBeenLastCalledWith({ where: {}, limite: undefined });
  });
});

describe('notificarGuardiaSolicitud', () => {
  it('responde 404 si la solicitud no existe', async () => {
    repo.buscarPorId.mockResolvedValue(null);

    await expect(
      notificarGuardiaSolicitud({ usuarioId: 'u1', rol: RolUsuario.ESTUDIANTE, solicitudId: 's9' })
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it('solo el solicitante o central pueden reiterar', async () => {
    repo.buscarPorId.mockResolvedValue(crearSolicitud());

    await expect(
      notificarGuardiaSolicitud({
        usuarioId: 'otro',
        rol: RolUsuario.ESTUDIANTE,
        solicitudId: 's1'
      })
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it('no reitera si el guardia ya va en camino', async () => {
    repo.buscarPorId.mockResolvedValue(
      crearSolicitud({ estado: EstadoSolicitudGuardia.EN_CAMINO, respondidaPorGuardiaEn: hace(5) })
    );

    await expect(
      notificarGuardiaSolicitud({ usuarioId: 'u1', rol: RolUsuario.ESTUDIANTE, solicitudId: 's1' })
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it('no reitera una solicitud cerrada', async () => {
    repo.buscarPorId.mockResolvedValue(crearSolicitud({ estado: EstadoSolicitudGuardia.RESUELTA }));

    await expect(
      notificarGuardiaSolicitud({ usuarioId: 'u1', rol: RolUsuario.ESTUDIANTE, solicitudId: 's1' })
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it('sin guardia asignado la reiteracion avisa a central', async () => {
    repo.buscarPorId.mockResolvedValue(
      crearSolicitud({ estado: EstadoSolicitudGuardia.PENDIENTE, guardiaAsignado: null })
    );
    repo.actualizar.mockResolvedValue(
      crearSolicitud({ estado: EstadoSolicitudGuardia.PENDIENTE, guardiaAsignado: null })
    );

    await notificarGuardiaSolicitud({
      usuarioId: 'u1',
      rol: RolUsuario.ESTUDIANTE,
      solicitudId: 's1',
      mensaje: '  sigo esperando  '
    });

    expect(repo.actualizar).toHaveBeenCalledWith('s1', { mensaje: 'sigo esperando' }, {});
    expect(notificarUsuariosPorRol).toHaveBeenCalledWith(
      expect.objectContaining({ titulo: 'Atención pendiente' }),
      {},
      expect.any(Array)
    );
    expect(registrarAuditoria).toHaveBeenCalledWith(
      expect.objectContaining({ accion: 'SOLICITUD_GUARDIA_REITERADA_SIN_GUARDIA' }),
      {}
    );
  });

  it('una solicitud pendiente con guardia pasa a notificada', async () => {
    repo.buscarPorId.mockResolvedValue(
      crearSolicitud({ estado: EstadoSolicitudGuardia.PENDIENTE })
    );

    await notificarGuardiaSolicitud({
      usuarioId: 'a1',
      rol: RolUsuario.ADMIN_CENTRAL,
      solicitudId: 's1'
    });

    expect(repo.actualizar).toHaveBeenCalledWith(
      's1',
      expect.objectContaining({ estado: EstadoSolicitudGuardia.NOTIFICADA }),
      {}
    );
    expect(registrarAuditoria).toHaveBeenCalledWith(
      expect.objectContaining({ accion: 'SOLICITUD_GUARDIA_RENOTIFICADA' }),
      {}
    );
  });
});

describe('actualizarEstadoSolicitudGuardia', () => {
  it('un usuario comun no puede cambiar el estado', async () => {
    await expect(
      actualizarEstadoSolicitudGuardia(
        'u1',
        RolUsuario.ESTUDIANTE,
        's1',
        EstadoSolicitudGuardia.RESUELTA
      )
    ).rejects.toMatchObject({ statusCode: 403 });
    expect(repo.ejecutarEnTransaccion).not.toHaveBeenCalled();
  });

  it('responde 404 si la solicitud no existe', async () => {
    repo.buscarPorId.mockResolvedValue(null);

    await expect(
      actualizarEstadoSolicitudGuardia(
        'g1',
        RolUsuario.GUARDIA,
        's9',
        EstadoSolicitudGuardia.EN_CAMINO
      )
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it('un guardia no puede atender solicitudes de otro guardia', async () => {
    repo.buscarPorId.mockResolvedValue(crearSolicitud());

    await expect(
      actualizarEstadoSolicitudGuardia(
        'g2',
        RolUsuario.GUARDIA,
        's1',
        EstadoSolicitudGuardia.EN_CAMINO
      )
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it('el guardia en camino avisa al solicitante y a central', async () => {
    repo.buscarPorId.mockResolvedValue(crearSolicitud());

    await actualizarEstadoSolicitudGuardia(
      'g1',
      RolUsuario.GUARDIA,
      's1',
      EstadoSolicitudGuardia.EN_CAMINO
    );

    expect(repo.actualizar).toHaveBeenCalledWith(
      's1',
      expect.objectContaining({
        estado: EstadoSolicitudGuardia.EN_CAMINO,
        respondidaPorGuardiaEn: expect.any(Date),
        enCaminoEn: expect.any(Date),
        resueltaEn: null
      }),
      {}
    );
    expect(crearNotificacion).toHaveBeenCalledWith(
      expect.objectContaining({
        usuarioId: 'u1',
        titulo: 'Guardia en camino',
        mensaje: 'El guardia va en camino a Biblioteca.',
        datos: expect.objectContaining({ alcance: 'PROPIO' })
      }),
      {},
      expect.any(Array)
    );
    expect(notificarUsuariosPorRol).toHaveBeenCalledWith(
      expect.objectContaining({
        titulo: 'Guardia en camino',
        datos: expect.not.objectContaining({ alcance: 'PROPIO' })
      }),
      {},
      expect.any(Array)
    );
  });

  it('el guardia la resuelve sin nota obligatoria', async () => {
    repo.buscarPorId.mockResolvedValue(
      crearSolicitud({ estado: EstadoSolicitudGuardia.EN_CAMINO })
    );

    await actualizarEstadoSolicitudGuardia(
      'g1',
      RolUsuario.GUARDIA,
      's1',
      EstadoSolicitudGuardia.RESUELTA
    );

    expect(crearNotificacion).toHaveBeenCalledWith(
      expect.objectContaining({
        titulo: 'Solicitud resuelta',
        mensaje: 'Tu solicitud en Biblioteca fue atendida.'
      }),
      {},
      expect.any(Array)
    );
  });

  it('central debe indicar un motivo para cerrar', async () => {
    repo.buscarPorId.mockResolvedValue(crearSolicitud());

    await expect(
      actualizarEstadoSolicitudGuardia(
        'a1',
        RolUsuario.ADMIN_CENTRAL,
        's1',
        EstadoSolicitudGuardia.CANCELADA,
        '  '
      )
    ).rejects.toMatchObject({ statusCode: 400 });
  });

  it('el cierre de central llega al usuario con la nota', async () => {
    repo.buscarPorId.mockResolvedValue(crearSolicitud());

    await actualizarEstadoSolicitudGuardia(
      'a1',
      RolUsuario.ADMIN_CENTRAL,
      's1',
      EstadoSolicitudGuardia.CANCELADA,
      'Solicitud duplicada'
    );

    expect(repo.actualizar).toHaveBeenCalledWith(
      's1',
      expect.objectContaining({
        motivoCierre: 'Solicitud duplicada',
        resueltaEn: expect.any(Date),
        cerradaPorUsuario: { connect: { id: 'a1' } }
      }),
      {}
    );
    expect(crearNotificacion).toHaveBeenCalledWith(
      expect.objectContaining({
        titulo: 'Solicitud cancelada',
        mensaje: 'Tu solicitud en Biblioteca fue cancelada. Motivo de central: Solicitud duplicada'
      }),
      {},
      expect.any(Array)
    );
    expect(crearNotificacion).toHaveBeenCalledWith(
      expect.objectContaining({
        usuarioId: 'g1',
        titulo: 'Solicitud cerrada',
        mensaje: 'Central cerró la solicitud de Ana Rojas en Biblioteca. Ya no es necesario ir.'
      }),
      {},
      expect.any(Array)
    );
  });

  it('central puede volver a avisar al guardia pasado el minuto', async () => {
    repo.buscarPorId.mockResolvedValue(crearSolicitud());

    await actualizarEstadoSolicitudGuardia(
      'a1',
      RolUsuario.ADMINISTRADOR,
      's1',
      EstadoSolicitudGuardia.NOTIFICADA
    );

    expect(repo.actualizar).toHaveBeenCalledWith(
      's1',
      expect.objectContaining({ notificacionesGuardia: { increment: 1 } }),
      {}
    );
    expect(crearNotificacion).toHaveBeenCalledWith(
      expect.objectContaining({ usuarioId: 'g1', titulo: 'Recordatorio de solicitud' }),
      {},
      expect.any(Array)
    );
  });

  it.each([
    ['antes del minuto', { notificadaGuardiaEn: hace(5) }],
    ['sin guardia asignado', { guardiaAsignado: null }],
    ['si el guardia ya respondio', { respondidaPorGuardiaEn: hace(30) }]
  ])('central no puede reenviar el aviso %s', async (_caso, cambios) => {
    repo.buscarPorId.mockResolvedValue(crearSolicitud(cambios));

    await expect(
      actualizarEstadoSolicitudGuardia(
        'a1',
        RolUsuario.ADMIN_CENTRAL,
        's1',
        EstadoSolicitudGuardia.NOTIFICADA
      )
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it('un guardia no puede reenviarse el aviso a si mismo', async () => {
    repo.buscarPorId.mockResolvedValue(crearSolicitud());

    await expect(
      actualizarEstadoSolicitudGuardia(
        'g1',
        RolUsuario.GUARDIA,
        's1',
        EstadoSolicitudGuardia.NOTIFICADA
      )
    ).rejects.toMatchObject({ statusCode: 403 });
  });
});

describe('quién puede cerrar una solicitud', () => {
  it('central ya no puede marcarla como resuelta', async () => {
    await expect(
      actualizarEstadoSolicitudGuardia(
        'a1',
        RolUsuario.ADMIN_CENTRAL,
        's1',
        EstadoSolicitudGuardia.RESUELTA,
        'Atendida'
      )
    ).rejects.toMatchObject({
      statusCode: 403,
      message: 'Solo el guardia que atendió la solicitud puede marcarla como resuelta'
    });
    expect(repo.actualizar).not.toHaveBeenCalled();
  });

  it.each([EstadoSolicitudGuardia.CANCELADA, EstadoSolicitudGuardia.PENDIENTE])(
    'el guardia no puede pasarla a %s',
    async (estado) => {
      await expect(
        actualizarEstadoSolicitudGuardia('g1', RolUsuario.GUARDIA, 's1', estado)
      ).rejects.toMatchObject({ statusCode: 403 });
      expect(repo.actualizar).not.toHaveBeenCalled();
    }
  );

  it('el guardia que la resuelve queda registrado como quien la cerró', async () => {
    repo.buscarPorId.mockResolvedValue(crearSolicitud());

    await actualizarEstadoSolicitudGuardia(
      'g1',
      RolUsuario.GUARDIA,
      's1',
      EstadoSolicitudGuardia.RESUELTA
    );

    expect(repo.actualizar).toHaveBeenCalledWith(
      's1',
      expect.objectContaining({
        estado: EstadoSolicitudGuardia.RESUELTA,
        cerradaPorUsuario: { connect: { id: 'g1' } }
      }),
      {}
    );
  });
});

describe('cancelarSolicitudGuardia', () => {
  it('quien hizo la solicitud la cancela y el guardia asignado deja de ir', async () => {
    repo.buscarPorId.mockResolvedValue(
      crearSolicitud({ estado: EstadoSolicitudGuardia.EN_CAMINO })
    );

    await cancelarSolicitudGuardia('u1', 's1', ' Ya lo resolví ');

    expect(repo.actualizar).toHaveBeenCalledWith(
      's1',
      expect.objectContaining({
        estado: EstadoSolicitudGuardia.CANCELADA,
        motivoCierre: 'Ya lo resolví',
        resueltaEn: expect.any(Date),
        cerradaPorUsuario: { connect: { id: 'u1' } }
      }),
      {}
    );
    expect(crearNotificacion).toHaveBeenCalledWith(
      expect.objectContaining({
        usuarioId: 'g1',
        titulo: 'Solicitud cancelada',
        mensaje:
          'Ana Rojas canceló su solicitud en Biblioteca. Ya no es necesario ir. Motivo: Ya lo resolví'
      }),
      {},
      expect.any(Array)
    );
    expect(registrarAuditoria).toHaveBeenCalledWith(
      expect.objectContaining({ accion: 'SOLICITUD_GUARDIA_CANCELADA_POR_SOLICITANTE' }),
      {}
    );
  });

  it('sin guardia asignado se cancela sin avisar a nadie más', async () => {
    repo.buscarPorId.mockResolvedValue(
      crearSolicitud({ estado: EstadoSolicitudGuardia.PENDIENTE, guardiaAsignado: null })
    );

    await cancelarSolicitudGuardia('u1', 's1', 'Ya no necesito ayuda');

    expect(repo.actualizar).toHaveBeenCalledWith(
      's1',
      expect.objectContaining({
        estado: EstadoSolicitudGuardia.CANCELADA,
        motivoCierre: 'Ya no necesito ayuda'
      }),
      {}
    );
    expect(crearNotificacion).not.toHaveBeenCalled();
  });

  it('exige un motivo para cancelar', async () => {
    repo.buscarPorId.mockResolvedValue(crearSolicitud());

    await expect(cancelarSolicitudGuardia('u1', 's1', '   ')).rejects.toMatchObject({
      statusCode: 400,
      message: 'Debes indicar un motivo para cancelar la solicitud'
    });
    expect(repo.buscarPorId).not.toHaveBeenCalled();
    expect(repo.actualizar).not.toHaveBeenCalled();
  });

  it('otra persona no puede cancelarla', async () => {
    repo.buscarPorId.mockResolvedValue(crearSolicitud());

    await expect(cancelarSolicitudGuardia('otro', 's1', 'Ya lo resolví')).rejects.toMatchObject({
      statusCode: 403
    });
    expect(repo.actualizar).not.toHaveBeenCalled();
  });

  it('no se cancela una solicitud ya cerrada', async () => {
    repo.buscarPorId.mockResolvedValue(crearSolicitud({ estado: EstadoSolicitudGuardia.RESUELTA }));

    await expect(cancelarSolicitudGuardia('u1', 's1', 'Ya lo resolví')).rejects.toMatchObject({
      statusCode: 409
    });
  });

  it('responde 404 si la solicitud no existe', async () => {
    repo.buscarPorId.mockResolvedValue(null);

    await expect(cancelarSolicitudGuardia('u1', 's1', 'Ya lo resolví')).rejects.toMatchObject({
      statusCode: 404
    });
  });
});

describe('quién cerró la solicitud', () => {
  it.each([
    ['u1', 'SOLICITANTE'],
    ['g1', 'GUARDIA'],
    ['a1', 'CENTRAL'],
    [null, null]
  ])('si la cerró %s se informa %s', (cerradaPorUsuarioId, esperado) => {
    expect(mapearSolicitudGuardia(crearSolicitud({ cerradaPorUsuarioId }))).toMatchObject({
      cerradaPor: esperado
    });
  });
});
