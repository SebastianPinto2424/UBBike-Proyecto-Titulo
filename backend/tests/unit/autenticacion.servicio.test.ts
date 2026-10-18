import '../helpers/env-setup';
import '../helpers/prisma-mock';
import { prismaMock } from '../helpers/prisma-mock';

jest.mock('../../src/configuracion/redis', () => ({
  obtenerClienteRedis: jest.fn().mockResolvedValue(null)
}));

jest.mock('../../src/modulos/correos/correo.servicio', () => ({
  crearCorreoVerificacion: jest.fn().mockReturnValue({ asunto: 'Verificar', texto: '', html: '' }),
  crearCorreoCuentaVerificada: jest
    .fn()
    .mockReturnValue({ asunto: 'Verificada', texto: '', html: '' }),
  crearCorreoCambioContrasena: jest
    .fn()
    .mockReturnValue({ asunto: 'Cambiar', texto: '', html: '' }),
  crearCorreoContrasenaActualizada: jest
    .fn()
    .mockReturnValue({ asunto: 'Actualizada', texto: '', html: '' }),
  enviarCorreo: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/notificaciones/notificacion.servicio', () => ({
  crearNotificacion: jest.fn().mockResolvedValue(undefined),
  notificarUsuariosPorRol: jest.fn().mockResolvedValue(undefined),
  olvidarDispositivosDeUsuario: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/tiempo-real/tiempo-real', () => ({
  ...jest.requireActual('../../src/tiempo-real/tiempo-real'),
  cerrarSesionesTiempoReal: jest.fn()
}));

jest.mock('../../src/modulos/auditoria/auditoria.servicio', () => ({
  registrarAuditoria: jest.fn().mockResolvedValue(undefined)
}));

import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { olvidarDispositivosDeUsuario } from '../../src/modulos/notificaciones/notificacion.servicio';
import { cerrarSesionesTiempoReal } from '../../src/tiempo-real/tiempo-real';
import {
  iniciarSesion,
  registrarUsuario,
  verificarCorreo
} from '../../src/modulos/autenticacion/autenticacion.servicio';

const usuarioBase = {
  id: 'uuid-1',
  nombre: 'Juan Perez',
  correo: 'juan@alumnos.ubiobio.cl',
  rut: '12.345.678-9',
  rol: 'ESTUDIANTE' as const,
  contrasenaHash: '$2a$12$placeholder',
  correoVerificado: false,
  registroParcial: false,
  debeCambiarContrasena: false,
  cuentaActiva: true,
  versionSesion: 0,
  tokenVerificacionCorreo: null,
  tokenVerificacionCorreoExpiraEn: null,
  tokenCambioContrasena: null,
  tokenCambioContrasenaExpiraEn: null,
  eliminadoEn: null,
  creadoEn: new Date(),
  actualizadoEn: new Date()
};

describe('registrarUsuario', () => {
  it('lanza 409 si el correo ya existe', async () => {
    prismaMock.usuario.findUnique.mockResolvedValue(usuarioBase as any);

    await expect(
      registrarUsuario({
        nombre: 'Juan',
        correo: 'juan@alumnos.ubiobio.cl',
        contrasena: 'UBBike2026*Test!'
      })
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it('crea el usuario si el correo no existe', async () => {
    prismaMock.usuario.findUnique.mockResolvedValue(null);
    prismaMock.usuario.create.mockResolvedValue({
      ...usuarioBase,
      correoVerificado: false
    } as any);

    const resultado = await registrarUsuario({
      nombre: 'Juan',
      correo: 'juan@alumnos.ubiobio.cl',
      contrasena: 'UBBike2026*Test!'
    });

    expect(resultado.message).toContain('Registro recibido');
    expect(prismaMock.usuario.create).toHaveBeenCalled();
  });

  it('no hereda la identidad de una cuenta eliminada al reutilizar su RUT', async () => {
    const eliminado = {
      ...usuarioBase,
      id: 'uuid-eliminado',
      correo: 'correo.antiguo@alumnos.ubiobio.cl',
      cuentaActiva: false,
      eliminadoEn: new Date()
    };
    const nuevo = {
      ...usuarioBase,
      id: 'uuid-nuevo',
      nombre: 'Juan Nuevo',
      correo: 'correo.nuevo@alumnos.ubiobio.cl'
    };
    prismaMock.usuario.findUnique
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(eliminado as any);
    prismaMock.usuario.update.mockResolvedValue({ ...eliminado, rut: null } as any);
    prismaMock.usuario.create.mockResolvedValue(nuevo as any);

    const resultado = await registrarUsuario({
      nombre: nuevo.nombre,
      rut: eliminado.rut,
      correo: nuevo.correo,
      contrasena: 'UBBike2026*Test!'
    });

    expect(resultado.message).toContain('Registro recibido');
    expect(resultado.usuario.id).toBe(nuevo.id);
    expect(prismaMock.usuario.create).toHaveBeenCalled();
    expect(prismaMock.usuario.update).toHaveBeenCalledWith({
      where: { id: eliminado.id },
      data: expect.objectContaining({ rut: null })
    });
  });

  it('libera los identificadores de ambas cuentas eliminadas antes de crear la nueva', async () => {
    const eliminadoPorCorreo = {
      ...usuarioBase,
      id: 'uuid-correo',
      correo: 'correo.nuevo@alumnos.ubiobio.cl',
      rut: null,
      eliminadoEn: new Date()
    };
    const eliminadoPorRut = {
      ...usuarioBase,
      id: 'uuid-rut',
      correo: 'correo.antiguo@alumnos.ubiobio.cl',
      rut: '12.345.678-9',
      eliminadoEn: new Date()
    };
    prismaMock.usuario.findUnique
      .mockResolvedValueOnce(eliminadoPorCorreo as any)
      .mockResolvedValueOnce(eliminadoPorRut as any);
    prismaMock.usuario.update.mockResolvedValue(eliminadoPorCorreo as any);
    prismaMock.usuario.create.mockResolvedValue({
      ...usuarioBase,
      id: 'uuid-nuevo'
    } as any);

    await registrarUsuario({
      nombre: 'Juan Nuevo',
      rut: eliminadoPorRut.rut!,
      correo: eliminadoPorCorreo.correo,
      contrasena: 'UBBike2026*Test!'
    });

    expect(prismaMock.usuario.update).toHaveBeenCalledTimes(2);
    expect(prismaMock.usuario.create).toHaveBeenCalled();
  });
});

describe('iniciarSesion', () => {
  it('lanza 401 si el usuario no existe', async () => {
    prismaMock.usuario.findUnique.mockResolvedValue(null);

    await expect(
      iniciarSesion({ correo: 'noexiste@alumnos.ubiobio.cl', contrasena: 'cualquier' })
    ).rejects.toMatchObject({ statusCode: 401 });
  });

  it('lanza 403 si la cuenta esta desactivada', async () => {
    prismaMock.usuario.findUnique.mockResolvedValue({
      ...usuarioBase,
      cuentaActiva: false
    } as any);

    await expect(
      iniciarSesion({ correo: 'juan@alumnos.ubiobio.cl', contrasena: 'cualquier' })
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it('lanza 403 si el correo no esta verificado', async () => {
    prismaMock.usuario.findUnique.mockResolvedValue({
      ...usuarioBase,
      correoVerificado: false,
      cuentaActiva: true,
      registroParcial: false
    } as any);

    await expect(
      iniciarSesion({ correo: 'juan@alumnos.ubiobio.cl', contrasena: 'cualquier' })
    ).rejects.toMatchObject({ statusCode: 403 });
  });
});

describe('iniciarSesion en un dispositivo nuevo', () => {
  it('cierra la sesión de los demás dispositivos de la cuenta', async () => {
    prismaMock.usuario.findUnique.mockResolvedValue({
      ...usuarioBase,
      correoVerificado: true,
      versionSesion: 4
    } as any);
    prismaMock.usuario.update.mockResolvedValue({ ...usuarioBase, versionSesion: 5 } as any);
    jest.spyOn(bcrypt, 'compare').mockResolvedValue(true as never);

    const resultado = await iniciarSesion({
      correo: 'juan@alumnos.ubiobio.cl',
      contrasena: 'ClaveSegura#2026'
    });

    expect(prismaMock.usuario.update).toHaveBeenCalledWith({
      where: { id: 'uuid-1' },
      data: { versionSesion: { increment: 1 } }
    });
    expect(olvidarDispositivosDeUsuario).toHaveBeenCalledWith('uuid-1');
    expect(cerrarSesionesTiempoReal).toHaveBeenCalledWith('uuid-1');
    expect((jwt.decode(resultado.token) as { versionSesion: number }).versionSesion).toBe(5);
  });
});

describe('verificarCorreo', () => {
  it('lanza 400 si el token no corresponde a ningun usuario', async () => {
    prismaMock.usuario.findFirst.mockResolvedValue(null);

    await expect(verificarCorreo('token-invalido')).rejects.toMatchObject({ statusCode: 400 });
  });

  it('lanza 400 si el token esta expirado', async () => {
    const fechaPasada = new Date(Date.now() - 1000 * 60 * 60);
    prismaMock.usuario.findFirst.mockResolvedValue({
      ...usuarioBase,
      tokenVerificacionCorreo: 'hash-token',
      tokenVerificacionCorreoExpiraEn: fechaPasada,
      registroParcial: false
    } as any);
    prismaMock.usuario.update.mockResolvedValue(usuarioBase as any);

    await expect(verificarCorreo('token-cualquiera')).rejects.toMatchObject({ statusCode: 400 });
  });
});
