import '../apoyo/configurar-entorno';
import '../apoyo/prisma-simulado';
import { prismaSimulado } from '../apoyo/prisma-simulado';

jest.mock('../../src/modulos/correos/cuenta.plantillas', () => ({
  crearCorreoCompletarRegistro: jest.fn()
}));

jest.mock('../../src/modulos/correos/operacion.plantillas', () => ({
  crearCorreoMovimiento: jest.fn()
}));

jest.mock('../../src/modulos/correos/correo.servicio', () => ({
  enviarCorreo: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/auditoria/auditoria.servicio', () => ({
  registrarAuditoria: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/notificaciones/notificacion.servicio', () => ({
  crearNotificacion: jest.fn().mockResolvedValue(undefined),
  notificarUsuariosPorRol: jest.fn().mockResolvedValue(undefined)
}));

import { registrarGestionManual } from '../../src/modulos/acceso/operaciones/gestion-manual.servicio';
import { TipoMovimiento } from '../../src/modulos/historial/tipo-movimiento';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';

describe('registrarGestionManual', () => {
  it('bloquea el retiro manual si el usuario tiene registro parcial (debe completar registro)', async () => {
    prismaSimulado.usuario.findFirst.mockResolvedValue({
      id: 'user-uuid-1',
      correo: 'estudiante@alumnos.ubiobio.cl',
      rut: '11.111.111-1',
      registroParcial: true
    } as never);

    await expect(
      registrarGestionManual({
        guardiaId: 'guardia-uuid-1',
        rol: RolUsuario.GUARDIA,
        correo: 'estudiante@alumnos.ubiobio.cl',
        rut: '11.111.111-1',
        tipo: TipoMovimiento.RETIRO
      })
    ).rejects.toMatchObject({ statusCode: 409 });

    expect(prismaSimulado.movimiento.create).not.toHaveBeenCalled();
  });
});
