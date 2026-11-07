import '../apoyo/configurar-entorno';
import '../apoyo/prisma-simulado';
import { prismaSimulado } from '../apoyo/prisma-simulado';
import bcrypt from 'bcrypt';

jest.mock('../../src/configuracion/redis', () => ({
  obtenerClienteRedis: jest.fn().mockResolvedValue(null)
}));

jest.mock('../../src/modulos/notificaciones/notificacion.servicio', () => ({
  crearNotificacion: jest.fn().mockResolvedValue(undefined),
  notificarUsuariosPorRol: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/auditoria/auditoria.servicio', () => ({
  registrarAuditoria: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/correos/cuenta.plantillas', () => ({
  crearCorreoCambioContrasena: jest.fn().mockReturnValue({ asunto: '', texto: '', html: '' }),
  crearCorreoContrasenaActualizada: jest
    .fn()
    .mockReturnValue({ asunto: 'Contrasena actualizada', texto: 'texto', html: 'html' }),
  crearCorreoCuentaVerificada: jest.fn().mockReturnValue({ asunto: '', texto: '', html: '' }),
  crearCorreoVerificacion: jest.fn().mockReturnValue({ asunto: '', texto: '', html: '' })
}));

jest.mock('../../src/modulos/correos/correo.servicio', () => ({
  enviarCorreo: jest.fn().mockResolvedValue(undefined)
}));

import { cambiarContrasenaSesion } from '../../src/modulos/autenticacion/contrasena.servicio';
import { crearCorreoContrasenaActualizada } from '../../src/modulos/correos/cuenta.plantillas';
import { enviarCorreo } from '../../src/modulos/correos/correo.servicio';

const TEMP = 'TempClave2026!!';
const NUEVA = 'NuevaClave2026!!';

let hashTemp: string;

const usuario = () => ({
  id: 'guardia-1',
  nombre: 'Guardia Demo',
  correo: 'guardia.demo@gmail.com',
  rut: null,
  rol: 'GUARDIA',
  contrasenaHash: hashTemp,
  correoVerificado: true,
  registroParcial: false,
  debeCambiarContrasena: true,
  cuentaActiva: true,
  versionSesion: 0
});

beforeAll(async () => {
  hashTemp = await bcrypt.hash(TEMP, 12);
});

describe('cambiarContrasenaSesion', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('rechaza con 400 si la contraseña actual es incorrecta', async () => {
    prismaSimulado.usuario.findUnique.mockResolvedValue(usuario() as never);

    await expect(
      cambiarContrasenaSesion('guardia-1', 'IncorrectaXXX1!', NUEVA)
    ).rejects.toMatchObject({ statusCode: 400 });

    expect(prismaSimulado.usuario.update).not.toHaveBeenCalled();
  });

  it('rechaza con 400 si la nueva contraseña es igual a la actual', async () => {
    prismaSimulado.usuario.findUnique.mockResolvedValue(usuario() as never);

    await expect(cambiarContrasenaSesion('guardia-1', TEMP, TEMP)).rejects.toMatchObject({
      statusCode: 400
    });

    expect(prismaSimulado.usuario.update).not.toHaveBeenCalled();
  });

  it('actualiza la contraseña y limpia el flag debeCambiarContrasena', async () => {
    prismaSimulado.usuario.findUnique.mockResolvedValue(usuario() as never);
    prismaSimulado.usuario.update.mockResolvedValue(usuario() as never);

    await cambiarContrasenaSesion('guardia-1', TEMP, NUEVA);

    expect(prismaSimulado.usuario.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'guardia-1' },
        data: expect.objectContaining({ debeCambiarContrasena: false })
      })
    );
    expect(crearCorreoContrasenaActualizada).toHaveBeenCalledWith(usuario().nombre);
    expect(enviarCorreo).toHaveBeenCalledWith(
      expect.objectContaining({
        para: usuario().correo,
        asunto: 'Contrasena actualizada'
      })
    );
  });
});
