import '../helpers/env-setup';
import '../helpers/prisma-mock';
import { prismaMock } from '../helpers/prisma-mock';

jest.mock('../../src/modulos/notificaciones/notificacion.servicio', () => ({
  crearNotificacion: jest.fn().mockResolvedValue(undefined),
  notificarUsuariosPorRol: jest.fn().mockResolvedValue(undefined),
  ejecutarEfectosDiferidos: jest.fn()
}));

jest.mock('../../src/modulos/auditoria/auditoria.servicio', () => ({
  registrarAuditoria: jest.fn().mockResolvedValue(undefined)
}));

import {
  actualizarEstadoIncidencia,
  crearIncidencia
} from '../../src/modulos/incidencias/incidencia.servicio';
import { crearNotificacion } from '../../src/modulos/notificaciones/notificacion.servicio';
import { TipoIncidencia } from '../../src/modulos/incidencias/tipo-incidencia';
import { EstadoIncidencia } from '../../src/modulos/incidencias/estado-incidencia';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';

const incidenciaCerradaBase = {
  id: 'inc-uuid-1',
  estado: EstadoIncidencia.RESUELTA,
  reportadaPorUsuarioId: 'user-uuid-1',
  respuesta: 'ya resuelta',
  bicicletero: { id: 'bic-uuid-1', nombre: 'Bicicletero FACE', ubicacion: 'FACE' }
};

describe('actualizarEstadoIncidencia', () => {
  it('no permite reabrir una incidencia cerrada (RESUELTA -> EN_REVISION)', async () => {
    prismaMock.incidencia.findUnique.mockResolvedValue(incidenciaCerradaBase as never);

    await expect(
      actualizarEstadoIncidencia({
        usuarioId: 'admin-uuid-1',
        rol: RolUsuario.ADMIN_CENTRAL,
        incidenciaId: 'inc-uuid-1',
        estado: EstadoIncidencia.EN_REVISION
      })
    ).rejects.toMatchObject({ statusCode: 409 });

    expect(prismaMock.incidencia.update).not.toHaveBeenCalled();
  });

  it('tampoco permite reabrir una incidencia DESCARTADA', async () => {
    prismaMock.incidencia.findUnique.mockResolvedValue({
      ...incidenciaCerradaBase,
      estado: EstadoIncidencia.DESCARTADA
    } as never);

    await expect(
      actualizarEstadoIncidencia({
        usuarioId: 'admin-uuid-1',
        rol: RolUsuario.ADMIN_CENTRAL,
        incidenciaId: 'inc-uuid-1',
        estado: EstadoIncidencia.PENDIENTE
      })
    ).rejects.toMatchObject({ statusCode: 409 });
  });
});

describe('crearIncidencia', () => {
  it('confirma con una notificación a quien reporta', async () => {
    const bicicletero = {
      id: 'bic-uuid-1',
      nombre: 'Bicicletero FACE',
      ubicacion: 'FACE',
      activo: true
    };
    prismaMock.bicicletero.findUnique.mockResolvedValue(bicicletero as never);
    prismaMock.usuario.findMany.mockResolvedValue([]);
    prismaMock.incidencia.create.mockResolvedValue({
      id: 'inc-uuid-2',
      tipo: TipoIncidencia.OTRO,
      descripcion: 'Candado roto en la entrada',
      estado: EstadoIncidencia.PENDIENTE,
      respuesta: null,
      creadaEn: new Date(),
      actualizadaEn: new Date(),
      resueltaEn: null,
      ultimoRecordatorioEn: null,
      recordatorios: 0,
      reportadaPorUsuarioId: 'user-uuid-1',
      reportadaPorUsuario: {
        id: 'user-uuid-1',
        nombre: 'Ana',
        correo: 'ana@alumnos.ubiobio.cl',
        rut: null,
        rol: RolUsuario.ESTUDIANTE
      },
      gestionadaPorUsuario: null,
      bicicletero,
      bicicleta: null,
      fotos: []
    } as never);

    await crearIncidencia({
      usuarioId: 'user-uuid-1',
      rol: RolUsuario.ESTUDIANTE,
      bicicleteroId: 'bic-uuid-1',
      tipo: TipoIncidencia.OTRO,
      descripcion: 'Candado roto en la entrada'
    });

    const avisos = jest.mocked(crearNotificacion).mock.calls.map(([aviso]) => aviso);
    expect(avisos).toContainEqual(
      expect.objectContaining({
        usuarioId: 'user-uuid-1',
        titulo: 'Incidencia registrada',
        tipo: 'INCIDENCIA',
        datos: expect.objectContaining({ incidenciaId: 'inc-uuid-2' }),
        soloRegistro: true
      })
    );
  });
});
