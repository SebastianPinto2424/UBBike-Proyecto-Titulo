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

import { actualizarEstadoIncidencia } from '../../src/modulos/incidencias/incidencia.servicio';
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
