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

jest.mock('../../src/tiempo-real/tiempo-real', () => ({
  EventosTiempoReal: {
    SOLICITUD: 'solicitud'
  },
  emitirTiempoReal: jest.fn(),
  salaRol: (rol: string) => `rol:${rol}`,
  salaUsuario: (usuarioId: string) => `usuario:${usuarioId}`
}));

import { actualizarEstadoSolicitudGuardia } from '../../src/modulos/acceso/solicitudes/solicitud-guardia.servicio';
import { EstadoSolicitudGuardia } from '../../src/modulos/acceso/solicitudes/estado-solicitud-guardia';
import { emitirTiempoReal } from '../../src/tiempo-real/tiempo-real';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';

const solicitudCerradaBase = {
  id: 'sol-uuid-1',
  estado: EstadoSolicitudGuardia.RESUELTA,
  guardiaAsignado: null,
  solicitadaPorUsuario: {
    id: 'user-uuid-1',
    nombre: 'Estudiante',
    correo: 'estudiante@alumnos.ubiobio.cl',
    rut: null,
    rol: RolUsuario.ESTUDIANTE
  },
  bicicletero: { id: 'bic-uuid-1', nombre: 'Bicicletero FACE', ubicacion: 'FACE' }
};

describe('actualizarEstadoSolicitudGuardia', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('no permite reabrir una solicitud ya cerrada (RESUELTA -> EN_CAMINO)', async () => {
    prismaMock.solicitudGuardia.findUnique.mockResolvedValue(solicitudCerradaBase as never);

    await expect(
      actualizarEstadoSolicitudGuardia(
        'admin-uuid-1',
        RolUsuario.ADMIN_CENTRAL,
        'sol-uuid-1',
        EstadoSolicitudGuardia.EN_CAMINO
      )
    ).rejects.toMatchObject({ statusCode: 409 });

    expect(prismaMock.solicitudGuardia.update).not.toHaveBeenCalled();
  });

  it('tampoco permite reabrir una solicitud CANCELADA', async () => {
    prismaMock.solicitudGuardia.findUnique.mockResolvedValue({
      ...solicitudCerradaBase,
      estado: EstadoSolicitudGuardia.CANCELADA
    } as never);

    await expect(
      actualizarEstadoSolicitudGuardia(
        'admin-uuid-1',
        RolUsuario.ADMIN_CENTRAL,
        'sol-uuid-1',
        EstadoSolicitudGuardia.EN_CAMINO
      )
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it('notifica por tiempo real al usuario solicitante cuando el guardia va en camino', async () => {
    const solicitudActiva = {
      ...solicitudCerradaBase,
      estado: EstadoSolicitudGuardia.NOTIFICADA,
      guardiaAsignado: {
        id: 'guardia-uuid-1',
        nombre: 'Guardia',
        correo: 'guardia@ubiobio.cl',
        rut: null,
        rol: RolUsuario.GUARDIA
      },
      respondidaPorGuardiaEn: null,
      enCaminoEn: null,
      resueltaEn: null,
      notificadaGuardiaEn: new Date('2026-07-08T12:00:00.000Z'),
      notificacionesGuardia: 1
    };
    const solicitudActualizada = {
      ...solicitudActiva,
      estado: EstadoSolicitudGuardia.EN_CAMINO,
      respondidaPorGuardiaEn: new Date('2026-07-08T12:01:00.000Z'),
      enCaminoEn: new Date('2026-07-08T12:01:00.000Z')
    };

    prismaMock.solicitudGuardia.findUnique.mockResolvedValue(solicitudActiva as never);
    prismaMock.solicitudGuardia.update.mockResolvedValue(solicitudActualizada as never);

    await actualizarEstadoSolicitudGuardia(
      'guardia-uuid-1',
      RolUsuario.GUARDIA,
      'sol-uuid-1',
      EstadoSolicitudGuardia.EN_CAMINO
    );

    expect(emitirTiempoReal).toHaveBeenCalledWith(
      expect.arrayContaining(['usuario:user-uuid-1']),
      'solicitud'
    );
  });
});
