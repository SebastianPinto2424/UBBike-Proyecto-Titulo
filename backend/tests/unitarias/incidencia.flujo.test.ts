import '../apoyo/configurar-entorno';

jest.mock('../../src/modulos/incidencias/incidencia.repositorio', () => ({
  ejecutarEnTransaccion: jest.fn(),
  buscarBicicleterosAsignados: jest.fn(),
  buscarBicicletero: jest.fn(),
  buscarBicicletaActiva: jest.fn(),
  crear: jest.fn(),
  buscarUsuariosPorRoles: jest.fn(),
  listar: jest.fn(),
  buscarPorId: jest.fn(),
  actualizar: jest.fn()
}));

jest.mock('../../src/modulos/incidencias/foto-incidencia.servicio', () => ({
  guardarFotosIncidencia: jest.fn(),
  eliminarArchivosFotosIncidencia: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/correos/operacion.plantillas', () => ({
  crearCorreoIncidenciaNueva: jest.fn().mockReturnValue({ asunto: 'a', texto: 't', html: 'h' }),
  crearCorreoIncidenciaResuelta: jest.fn().mockReturnValue({ asunto: 'a', texto: 't', html: 'h' })
}));

jest.mock('../../src/modulos/correos/correo.servicio', () => ({
  enviarCorreo: jest.fn().mockResolvedValue(undefined)
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
  EventosTiempoReal: { INCIDENCIA: 'incidencia' },
  emitirTiempoReal: jest.fn(),
  salaRol: (rol: string) => `rol:${rol}`,
  salaUsuario: (usuarioId: string) => `usuario:${usuarioId}`
}));

import * as repositorio from '../../src/modulos/incidencias/incidencia.repositorio';
import {
  actualizarEstadoIncidencia,
  recordarIncidencia
} from '../../src/modulos/incidencias/seguimiento-incidencia.servicio';
import {
  crearIncidencia,
  listarIncidencias
} from '../../src/modulos/incidencias/incidencia.servicio';
import { EstadoIncidencia } from '../../src/modulos/incidencias/estado-incidencia';
import { TipoIncidencia } from '../../src/modulos/incidencias/tipo-incidencia';
import {
  eliminarArchivosFotosIncidencia,
  guardarFotosIncidencia
} from '../../src/modulos/incidencias/foto-incidencia.servicio';
import {
  crearCorreoIncidenciaNueva,
  crearCorreoIncidenciaResuelta
} from '../../src/modulos/correos/operacion.plantillas';
import { enviarCorreo } from '../../src/modulos/correos/correo.servicio';
import {
  crearNotificacion,
  notificarUsuariosPorRol
} from '../../src/modulos/notificaciones/notificacion.servicio';
import { registrarAuditoria } from '../../src/modulos/auditoria/auditoria.servicio';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';
import { emitirTiempoReal } from '../../src/tiempo-real/tiempo-real';

const repo = repositorio as jest.Mocked<typeof repositorio>;

const reportante = {
  id: 'u1',
  nombre: 'Ana Rojas',
  correo: 'ana@alumnos.ubiobio.cl',
  rut: null,
  rol: RolUsuario.ESTUDIANTE
};
const bicicletero = { id: 'r1', nombre: 'Biblioteca', ubicacion: 'Campus', activo: true };
const hace = (segundos: number) => new Date(Date.now() - segundos * 1000);

const crearIncidenciaCompleta = (cambios: Record<string, unknown> = {}) =>
  ({
    id: 'i1',
    tipo: TipoIncidencia.DANO_INFRAESTRUCTURA,
    descripcion: 'Soporte suelto',
    estado: EstadoIncidencia.PENDIENTE,
    respuesta: null,
    creadaEn: hace(600),
    actualizadaEn: hace(600),
    resueltaEn: null,
    ultimoRecordatorioEn: null,
    recordatorios: 0,
    reportadaPorUsuarioId: 'u1',
    reportadaPorUsuario: reportante,
    gestionadaPorUsuario: null,
    bicicletero,
    bicicleta: null,
    fotos: [],
    ...cambios
  }) as never;

beforeEach(() => {
  repo.ejecutarEnTransaccion.mockImplementation(((callback: (db: unknown) => unknown) =>
    callback({})) as never);
  repo.buscarUsuariosPorRoles.mockResolvedValue([
    { id: 'a1', nombre: 'Central', correo: 'central@ubiobio.cl' },
    { id: 'u1', nombre: 'Ana Rojas', correo: 'ana@alumnos.ubiobio.cl' }
  ] as never);
  (guardarFotosIncidencia as jest.Mock).mockResolvedValue([]);
});

describe('crearIncidencia', () => {
  const datos = {
    usuarioId: 'u1',
    rol: RolUsuario.ESTUDIANTE,
    bicicleteroId: 'r1',
    tipo: TipoIncidencia.DANO_INFRAESTRUCTURA,
    descripcion: 'Soporte suelto'
  };

  it('guarda las fotos, avisa a central y envia correo a central sin incluir al reportante', async () => {
    (guardarFotosIncidencia as jest.Mock).mockResolvedValue([
      {
        fotoUrl: '/uploads/i/1.jpg',
        fotoNombreArchivo: '1.jpg',
        fotoMimeType: 'image/jpeg',
        fotoTamanoBytes: 10
      }
    ]);
    repo.buscarBicicletero.mockResolvedValue(bicicletero as never);
    repo.crear.mockResolvedValue(
      crearIncidenciaCompleta({
        creadaEn: new Date(),
        fotos: [{ id: 'f1', fotoUrl: '/uploads/i/1.jpg', mimeType: 'image/jpeg', tamanoBytes: 10 }]
      })
    );

    const incidencia = await crearIncidencia({ ...datos, fotos: ['data:image/jpeg;base64,AAAA'] });

    expect(repo.crear).toHaveBeenCalledWith(
      expect.objectContaining({
        bicicletaId: null,
        fotos: { create: [expect.objectContaining({ nombreArchivo: '1.jpg' })] }
      }),
      {}
    );
    expect(notificarUsuariosPorRol).toHaveBeenCalledWith(
      expect.objectContaining({ titulo: 'Nueva incidencia reportada', excluirUsuarioId: 'u1' }),
      {},
      expect.any(Array)
    );
    expect(crearCorreoIncidenciaNueva).toHaveBeenCalledWith(
      expect.objectContaining({ tipo: 'Daño de infraestructura', recordatorio: false })
    );
    expect(enviarCorreo).toHaveBeenCalledTimes(1);
    expect(enviarCorreo).toHaveBeenCalledWith(
      expect.objectContaining({ para: 'central@ubiobio.cl', referencia: 'i1' }),
      {}
    );
    expect(emitirTiempoReal).toHaveBeenCalledWith(
      expect.arrayContaining(['rol:GUARDIA', 'rol:ADMIN_CENTRAL']),
      'incidencia'
    );
    expect(incidencia.fotos).toEqual([
      { id: 'f1', url: '/uploads/i/1.jpg', mimeType: 'image/jpeg', tamanoBytes: 10 }
    ]);
    expect(incidencia.puedeRecordar).toBe(false);
  });

  it('si algo falla borra las fotos ya guardadas', async () => {
    (guardarFotosIncidencia as jest.Mock).mockResolvedValue([
      {
        fotoUrl: '/u/1.jpg',
        fotoNombreArchivo: '1.jpg',
        fotoMimeType: 'image/jpeg',
        fotoTamanoBytes: 10
      }
    ]);
    repo.buscarBicicletero.mockResolvedValue(null);

    await expect(
      crearIncidencia({ ...datos, fotos: ['data:image/jpeg;base64,AAAA'] })
    ).rejects.toMatchObject({
      statusCode: 404
    });
    expect(eliminarArchivosFotosIncidencia).toHaveBeenCalledWith(['1.jpg']);
  });

  it('un guardia solo asocia bicicletas ajenas en su bicicletero asignado', async () => {
    repo.buscarBicicletero.mockResolvedValue(bicicletero as never);
    repo.buscarBicicleterosAsignados.mockResolvedValue([{ bicicleteroId: 'r2' }] as never);
    repo.buscarBicicletaActiva.mockResolvedValue({ id: 'b2', usuarioId: 'u1' } as never);

    await expect(
      crearIncidencia({ ...datos, usuarioId: 'g1', rol: RolUsuario.GUARDIA, bicicletaId: 'b2' })
    ).rejects.toMatchObject({
      statusCode: 403,
      message: 'Solo puedes asociar bicicletas de otras personas en tu bicicletero asignado'
    });
    expect(repo.crear).not.toHaveBeenCalled();
  });

  it('como usuario un guardia reporta en cualquier bicicletero con su bicicleta', async () => {
    repo.buscarBicicletero.mockResolvedValue(bicicletero as never);
    repo.buscarBicicleterosAsignados.mockResolvedValue([{ bicicleteroId: 'r2' }] as never);
    repo.buscarBicicletaActiva.mockResolvedValue({ id: 'b7', usuarioId: 'g1' } as never);
    repo.crear.mockResolvedValue(crearIncidenciaCompleta({ reportadaPorUsuarioId: 'g1' }));

    await crearIncidencia({
      ...datos,
      usuarioId: 'g1',
      rol: RolUsuario.GUARDIA,
      bicicletaId: 'b7'
    });
    await crearIncidencia({ ...datos, usuarioId: 'g1', rol: RolUsuario.GUARDIA });

    expect(repo.crear).toHaveBeenCalledTimes(2);
    expect(repo.buscarBicicleterosAsignados).not.toHaveBeenCalled();
  });

  it('valida la bicicleta asociada', async () => {
    repo.buscarBicicletero.mockResolvedValue(bicicletero as never);
    repo.buscarBicicletaActiva.mockResolvedValue(null);

    await expect(crearIncidencia({ ...datos, bicicletaId: 'b9' })).rejects.toMatchObject({
      statusCode: 404
    });

    repo.buscarBicicletaActiva.mockResolvedValue({ id: 'b2', usuarioId: 'otro' } as never);
    await expect(crearIncidencia({ ...datos, bicicletaId: 'b2' })).rejects.toMatchObject({
      statusCode: 403
    });
  });

  it('un guardia puede asociar la bicicleta de un usuario', async () => {
    repo.buscarBicicletero.mockResolvedValue(bicicletero as never);
    repo.buscarBicicleterosAsignados.mockResolvedValue([{ bicicleteroId: 'r1' }] as never);
    repo.buscarBicicletaActiva.mockResolvedValue({ id: 'b2', usuarioId: 'u1' } as never);
    repo.crear.mockResolvedValue(
      crearIncidenciaCompleta({
        reportadaPorUsuarioId: 'g1',
        bicicleta: {
          id: 'b2',
          descripcion: 'Urbana',
          marca: null,
          modelo: null,
          color: null,
          aro: null,
          numeroSerie: null,
          fotoUrl: null,
          activa: true,
          dentroBicicletero: true
        }
      })
    );

    const incidencia = await crearIncidencia({
      ...datos,
      usuarioId: 'g1',
      rol: RolUsuario.GUARDIA,
      bicicletaId: 'b2'
    });

    expect(repo.crear).toHaveBeenCalledWith(expect.objectContaining({ bicicletaId: 'b2' }), {});
    expect(incidencia.bicicleta).toMatchObject({ id: 'b2', dentroBicicletero: true });
  });
});

describe('listarIncidencias', () => {
  beforeEach(() => {
    repo.listar.mockResolvedValue([crearIncidenciaCompleta()]);
  });

  const where = () =>
    repo.listar.mock.calls.at(-1)?.[0].where as { AND?: Record<string, unknown>[] };

  it('un usuario comun ve solo sus reportes y puede recordarlos', async () => {
    const { incidencias, nextCursor } = await listarIncidencias({
      usuarioId: 'u1',
      rol: RolUsuario.FUNCIONARIO
    });

    expect(where()).toEqual({ AND: [{ reportadaPorUsuarioId: 'u1' }] });
    expect(incidencias[0].puedeRecordar).toBe(true);
    expect(nextCursor).toBeNull();
  });

  it('un guardia ve sus reportes y los de sus bicicleteros', async () => {
    repo.buscarBicicleterosAsignados.mockResolvedValue([{ bicicleteroId: 'r1' }] as never);

    const { incidencias } = await listarIncidencias({ usuarioId: 'g1', rol: RolUsuario.GUARDIA });

    expect(where()).toEqual({
      AND: [{ OR: [{ reportadaPorUsuarioId: 'g1' }, { bicicleteroId: { in: ['r1'] } }] }]
    });
    expect(incidencias[0].puedeRecordar).toBe(false);
    expect(incidencias[0].segundosParaRecordar).toBeNull();
  });

  it('un guardia sin asignacion ve solo sus reportes', async () => {
    repo.buscarBicicleterosAsignados.mockResolvedValue([] as never);

    await listarIncidencias({ usuarioId: 'g1', rol: RolUsuario.GUARDIA });

    expect(where()).toEqual({ AND: [{ OR: [{ reportadaPorUsuarioId: 'g1' }] }] });
  });

  it('el alcance propio muestra al personal solo lo que reporto', async () => {
    await listarIncidencias({ usuarioId: 'g1', rol: RolUsuario.GUARDIA, alcance: 'PROPIO' });
    expect(where()).toEqual({ AND: [{ reportadaPorUsuarioId: 'g1' }] });

    await listarIncidencias({ usuarioId: 'a1', rol: RolUsuario.ADMINISTRADOR, alcance: 'PROPIO' });
    expect(where()).toEqual({ AND: [{ reportadaPorUsuarioId: 'a1' }] });
    expect(repo.buscarBicicleterosAsignados).not.toHaveBeenCalled();
  });

  it('central combina filtros y busqueda', async () => {
    await listarIncidencias({
      usuarioId: 'a1',
      rol: RolUsuario.ADMIN_CENTRAL,
      estado: 'ABIERTAS',
      tipo: TipoIncidencia.PROBLEMA_QR,
      bicicleteroId: 'r1',
      q: ' soporte '
    });

    const condiciones = where().AND!;
    expect(condiciones[0]).toEqual({ estado: { notIn: ['RESUELTA', 'DESCARTADA'] } });
    expect(condiciones[1]).toEqual({ tipo: 'PROBLEMA_QR' });
    expect(condiciones[2]).toEqual({ bicicleteroId: 'r1' });
    expect((condiciones[3].OR as unknown[]).length).toBe(8);
  });

  it('central sin filtros ve todo y filtra por estado concreto', async () => {
    await listarIncidencias({
      usuarioId: 'a1',
      rol: RolUsuario.ADMINISTRADOR,
      estado: 'TODOS',
      tipo: 'TODOS'
    });
    expect(where()).toEqual({});

    await listarIncidencias({
      usuarioId: 'a1',
      rol: RolUsuario.ADMINISTRADOR,
      estado: EstadoIncidencia.EN_REVISION
    });
    expect(where()).toEqual({ AND: [{ estado: 'EN_REVISION' }] });
  });

  it.each([
    [{ estado: 'ABIERTO' }, 'Estado de incidencia inválido'],
    [{ tipo: 'ROBO' }, 'Tipo de incidencia inválido'],
    [{ cursor: 'no-es-uuid' }, 'Cursor de paginación inválido'],
    [{ limite: 0 }, 'El límite debe ser un entero positivo']
  ])('rechaza filtros invalidos %o', async (filtro, mensaje) => {
    await expect(
      listarIncidencias({ usuarioId: 'a1', rol: RolUsuario.ADMINISTRADOR, ...(filtro as object) })
    ).rejects.toMatchObject({ statusCode: 400, message: mensaje });
  });

  it('pagina con cursor', async () => {
    repo.listar.mockResolvedValue([
      crearIncidenciaCompleta({ id: 'i1' }),
      crearIncidenciaCompleta({ id: 'i2' }),
      crearIncidenciaCompleta({ id: 'i3' })
    ]);

    const resultado = await listarIncidencias({
      usuarioId: 'a1',
      rol: RolUsuario.ADMINISTRADOR,
      limite: 2
    });

    expect(repo.listar).toHaveBeenLastCalledWith(expect.objectContaining({ take: 3 }));
    expect(resultado.incidencias.map((i) => i.id)).toEqual(['i1', 'i2']);
    expect(resultado.nextCursor).toBe('i2');
  });
});

describe('actualizarEstadoIncidencia', () => {
  it('solo central gestiona incidencias', async () => {
    await expect(
      actualizarEstadoIncidencia({
        usuarioId: 'g1',
        rol: RolUsuario.GUARDIA,
        incidenciaId: 'i1',
        estado: EstadoIncidencia.EN_REVISION
      })
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it('responde 404 si no existe', async () => {
    repo.buscarPorId.mockResolvedValue(null);

    await expect(
      actualizarEstadoIncidencia({
        usuarioId: 'a1',
        rol: RolUsuario.ADMIN_CENTRAL,
        incidenciaId: 'i9',
        estado: EstadoIncidencia.EN_REVISION
      })
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it('exige respuesta para cerrar', async () => {
    repo.buscarPorId.mockResolvedValue(crearIncidenciaCompleta());

    await expect(
      actualizarEstadoIncidencia({
        usuarioId: 'a1',
        rol: RolUsuario.ADMIN_CENTRAL,
        incidenciaId: 'i1',
        estado: EstadoIncidencia.RESUELTA,
        respuesta: '   '
      })
    ).rejects.toMatchObject({ statusCode: 400 });
  });

  it('pasar a revision avisa al reportante sin correo', async () => {
    repo.buscarPorId.mockResolvedValue(crearIncidenciaCompleta());
    repo.actualizar.mockResolvedValue(
      crearIncidenciaCompleta({ estado: EstadoIncidencia.EN_REVISION })
    );

    await actualizarEstadoIncidencia({
      usuarioId: 'a1',
      rol: RolUsuario.ADMIN_CENTRAL,
      incidenciaId: 'i1',
      estado: EstadoIncidencia.EN_REVISION
    });

    expect(repo.actualizar).toHaveBeenCalledWith(
      'i1',
      expect.objectContaining({ gestionadaPorUsuarioId: 'a1', resueltaEn: null }),
      {}
    );
    expect(crearNotificacion).toHaveBeenCalledWith(
      expect.objectContaining({
        usuarioId: 'u1',
        mensaje: 'El estado del reporte en Biblioteca cambió a en revisión.'
      }),
      {},
      expect.any(Array)
    );
    expect(enviarCorreo).not.toHaveBeenCalled();
    expect(emitirTiempoReal).toHaveBeenCalledWith(
      expect.arrayContaining(['usuario:u1']),
      'incidencia'
    );
  });

  it('al resolver avisa y envia correo con la respuesta', async () => {
    repo.buscarPorId.mockResolvedValue(crearIncidenciaCompleta());
    repo.actualizar.mockResolvedValue(
      crearIncidenciaCompleta({ estado: EstadoIncidencia.RESUELTA })
    );

    await actualizarEstadoIncidencia({
      usuarioId: 'a1',
      rol: RolUsuario.ADMINISTRADOR,
      incidenciaId: 'i1',
      estado: EstadoIncidencia.RESUELTA,
      respuesta: ' Se reparó el soporte '
    });

    expect(repo.actualizar).toHaveBeenCalledWith(
      'i1',
      expect.objectContaining({ respuesta: 'Se reparó el soporte', resueltaEn: expect.any(Date) }),
      {}
    );
    expect(crearCorreoIncidenciaResuelta).toHaveBeenCalledWith(
      expect.objectContaining({ estado: 'resuelta', respuesta: 'Se reparó el soporte' })
    );
    expect(enviarCorreo).toHaveBeenCalledWith(
      expect.objectContaining({ para: 'ana@alumnos.ubiobio.cl' }),
      {}
    );
    expect(registrarAuditoria).toHaveBeenCalledWith(
      expect.objectContaining({
        accion: 'INCIDENCIA_ESTADO_ACTUALIZADO',
        datos: expect.objectContaining({ estadoAnterior: 'PENDIENTE', estadoNuevo: 'RESUELTA' })
      }),
      {}
    );
  });

  it('nadie de administracion gestiona una incidencia que reporto', async () => {
    repo.buscarPorId.mockResolvedValue(crearIncidenciaCompleta({ reportadaPorUsuarioId: 'a1' }));

    await expect(
      actualizarEstadoIncidencia({
        usuarioId: 'a1',
        rol: RolUsuario.ADMIN_CENTRAL,
        incidenciaId: 'i1',
        estado: EstadoIncidencia.DESCARTADA,
        respuesta: 'Duplicada'
      })
    ).rejects.toMatchObject({
      statusCode: 403,
      message:
        'No puedes gestionar una incidencia que reportaste. Debe revisarla otra persona de administración.'
    });
    expect(repo.actualizar).not.toHaveBeenCalled();
    expect(crearNotificacion).not.toHaveBeenCalled();
    expect(enviarCorreo).not.toHaveBeenCalled();
  });
});

describe('recordarIncidencia', () => {
  it('responde 404 si no existe', async () => {
    repo.buscarPorId.mockResolvedValue(null);

    await expect(
      recordarIncidencia({ usuarioId: 'u1', rol: RolUsuario.ESTUDIANTE, incidenciaId: 'i9' })
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it('solo quien reporto puede recordar', async () => {
    repo.buscarPorId.mockResolvedValue(crearIncidenciaCompleta());

    await expect(
      recordarIncidencia({ usuarioId: 'otro', rol: RolUsuario.ESTUDIANTE, incidenciaId: 'i1' })
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it('no recuerda una incidencia cerrada', async () => {
    repo.buscarPorId.mockResolvedValue(
      crearIncidenciaCompleta({ estado: EstadoIncidencia.RESUELTA })
    );

    await expect(
      recordarIncidencia({ usuarioId: 'u1', rol: RolUsuario.ESTUDIANTE, incidenciaId: 'i1' })
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it('espera cinco minutos entre recordatorios', async () => {
    repo.buscarPorId.mockResolvedValue(crearIncidenciaCompleta({ ultimoRecordatorioEn: hace(60) }));

    await expect(
      recordarIncidencia({ usuarioId: 'u1', rol: RolUsuario.ESTUDIANTE, incidenciaId: 'i1' })
    ).rejects.toMatchObject({ statusCode: 409, message: expect.stringContaining('segundos') });
  });

  it('registra el recordatorio, avisa a central y le envia correo', async () => {
    repo.buscarPorId.mockResolvedValue(crearIncidenciaCompleta());
    repo.actualizar.mockResolvedValue(
      crearIncidenciaCompleta({ ultimoRecordatorioEn: new Date(), recordatorios: 1 })
    );

    const incidencia = await recordarIncidencia({
      usuarioId: 'u1',
      rol: RolUsuario.ESTUDIANTE,
      incidenciaId: 'i1'
    });

    expect(repo.actualizar).toHaveBeenCalledWith(
      'i1',
      { ultimoRecordatorioEn: expect.any(Date), recordatorios: { increment: 1 } },
      {}
    );
    expect(notificarUsuariosPorRol).toHaveBeenCalledWith(
      expect.objectContaining({ titulo: 'Recordatorio de incidencia' }),
      {},
      expect.any(Array)
    );
    expect(crearCorreoIncidenciaNueva).toHaveBeenCalledWith(
      expect.objectContaining({ recordatorio: true })
    );
    expect(incidencia.recordatorios).toBe(1);
    expect(incidencia.puedeRecordar).toBe(false);
    expect(incidencia.segundosParaRecordar).toBeGreaterThan(0);
  });
});
