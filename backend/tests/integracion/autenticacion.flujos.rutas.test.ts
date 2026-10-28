import '../apoyo/configurar-entorno';

jest.mock('../../src/configuracion/redis', () => ({
  obtenerClienteRedis: jest.fn().mockResolvedValue(null)
}));

jest.mock('../../src/configuracion/prisma', () => ({
  prisma: {
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    usuario: { findUnique: jest.fn() }
  }
}));

jest.mock('../../src/modulos/autenticacion/registro.servicio', () => ({
  registrarUsuario: jest.fn().mockResolvedValue({ message: 'Revisa tu correo' }),
  verificarCorreo: jest.fn().mockResolvedValue({ message: 'Correo verificado correctamente' }),
  completarRegistro: jest.fn().mockResolvedValue({ message: 'Registro completado' })
}));

jest.mock('../../src/modulos/autenticacion/autenticacion.servicio', () => ({
  iniciarSesion: jest.fn(),
  obtenerUsuarioActual: jest.fn().mockResolvedValue({ id: 'u1', nombre: 'Ana Rojas' }),
  refrescarToken: jest.fn().mockResolvedValue({ token: 't2', refreshToken: 'r2' }),
  cerrarSesion: jest.fn().mockResolvedValue({ message: 'Sesión cerrada correctamente' })
}));

jest.mock('../../src/modulos/autenticacion/contrasena.servicio', () => ({
  solicitarCambioContrasena: jest.fn().mockResolvedValue({ message: 'Si el correo existe...' }),
  cambiarContrasena: jest.fn().mockResolvedValue({ message: 'Contraseña actualizada' }),
  cambiarContrasenaSesion: jest.fn().mockResolvedValue({ message: 'Contraseña actualizada' })
}));

import request from 'supertest';
import { aplicacion } from '../../src/aplicacion';
import { prisma } from '../../src/configuracion/prisma';
import * as sesion from '../../src/modulos/autenticacion/autenticacion.servicio';
import * as contrasena from '../../src/modulos/autenticacion/contrasena.servicio';
import * as registro from '../../src/modulos/autenticacion/registro.servicio';
import { crearTokenSesion } from '../../src/modulos/autenticacion/autenticacion.tokens';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';

const servicio = { ...sesion, ...contrasena, ...registro };

const clave = 'Bicicleta#2026ubb';
const token = 'a'.repeat(64);
const usuarioId = '00000000-0000-4000-8000-000000000001';

const autenticar = (cambios: Record<string, unknown> = {}) => {
  (prisma.usuario.findUnique as jest.Mock).mockResolvedValue({
    id: usuarioId,
    rol: RolUsuario.ESTUDIANTE,
    versionSesion: 1,
    cuentaActiva: true,
    correoVerificado: true,
    debeCambiarContrasena: false,
    ...cambios
  });
  return `Bearer ${crearTokenSesion(usuarioId, RolUsuario.ESTUDIANTE, 1)}`;
};

describe('registro', () => {
  it('acepta un registro institucional completo', async () => {
    const res = await request(aplicacion).post('/autenticacion/registro').send({
      nombre: 'Ana María Rojas Soto',
      rut: '11.111.111-1',
      correo: 'ana.rojas@alumnos.ubiobio.cl',
      contrasena: clave
    });

    expect(res.status).toBe(201);
    expect(servicio.registrarUsuario).toHaveBeenCalledWith(
      expect.objectContaining({ correo: 'ana.rojas@alumnos.ubiobio.cl' })
    );
  });

  it.each([
    ['correo externo', { correo: 'ana@gmail.com' }],
    ['contraseña débil', { contrasena: 'corta' }],
    ['RUT inválido', { rut: '11.111.111-2' }]
  ])('rechaza el registro con %s', async (_caso, cambio) => {
    const res = await request(aplicacion)
      .post('/autenticacion/registro')
      .send({
        nombre: 'Ana María Rojas Soto',
        rut: '11.111.111-1',
        correo: 'ana.rojas@alumnos.ubiobio.cl',
        contrasena: clave,
        ...cambio
      });

    expect(res.status).toBe(400);
    expect(servicio.registrarUsuario).not.toHaveBeenCalled();
  });
});

describe('enlaces de correo y contraseñas', () => {
  it('verifica el correo por cuerpo o por consulta', async () => {
    const porCuerpo = await request(aplicacion)
      .post('/autenticacion/verificar-correo')
      .send({ token });
    const porConsulta = await request(aplicacion).get(
      `/autenticacion/verificar-correo?token=${token}`
    );

    expect(porCuerpo.status).toBe(200);
    expect(porConsulta.status).toBe(200);
    expect(servicio.verificarCorreo).toHaveBeenNthCalledWith(1, token);
    expect(servicio.verificarCorreo).toHaveBeenNthCalledWith(2, token);
  });

  it('completa el registro con nombre y contraseña segura', async () => {
    const res = await request(aplicacion)
      .post('/autenticacion/completar-registro')
      .send({ token, nombre: 'Ana María Rojas Soto', contrasena: clave });

    expect(res.status).toBe(200);
    expect(servicio.completarRegistro).toHaveBeenCalledWith({
      token,
      nombre: 'Ana María Rojas Soto',
      contrasena: clave
    });
  });

  it('solicita y aplica el cambio de contraseña', async () => {
    const solicitud = await request(aplicacion)
      .post('/autenticacion/solicitar-cambio-contrasena')
      .send({ correo: 'ana.rojas@alumnos.ubiobio.cl' });
    const cambio = await request(aplicacion)
      .post('/autenticacion/cambiar-contrasena')
      .send({ token, contrasena: clave });
    const debil = await request(aplicacion)
      .post('/autenticacion/cambiar-contrasena')
      .send({ token, contrasena: 'simple' });

    expect(solicitud.status).toBe(200);
    expect(servicio.solicitarCambioContrasena).toHaveBeenCalledWith('ana.rojas@alumnos.ubiobio.cl');
    expect(cambio.status).toBe(200);
    expect(servicio.cambiarContrasena).toHaveBeenCalledWith(token, clave);
    expect(debil.status).toBe(400);
  });
});

describe('sesión', () => {
  it('entrega el perfil del usuario autenticado', async () => {
    const res = await request(aplicacion)
      .get('/autenticacion/perfil')
      .set('Authorization', autenticar());

    expect(res.status).toBe(200);
    expect(res.body.usuario).toEqual({ id: 'u1', nombre: 'Ana Rojas' });
  });

  it('permite cambiar la contraseña temporal con la sesión abierta', async () => {
    const res = await request(aplicacion)
      .post('/autenticacion/cambiar-contrasena-sesion')
      .set('Authorization', autenticar({ debeCambiarContrasena: true }))
      .send({ contrasenaActual: 'Temporal#2026x', contrasenaNueva: clave });

    expect(res.status).toBe(200);
    expect(servicio.cambiarContrasenaSesion).toHaveBeenCalledWith(
      usuarioId,
      'Temporal#2026x',
      clave
    );
  });

  it('renueva tokens solo con un usuario válido', async () => {
    const invalido = await request(aplicacion)
      .post('/autenticacion/refresh')
      .send({ usuarioId: 'no-es-uuid', refreshToken: 'r1' });
    const valido = await request(aplicacion)
      .post('/autenticacion/refresh')
      .send({ usuarioId, refreshToken: 'r1' });

    expect(invalido.status).toBe(400);
    expect(valido.status).toBe(200);
    expect(valido.body).toEqual({ token: 't2', refreshToken: 'r2' });
    expect(servicio.refrescarToken).toHaveBeenCalledWith(usuarioId, 'r1');
  });

  it('cierra la sesión del dispositivo', async () => {
    const res = await request(aplicacion)
      .post('/autenticacion/logout')
      .set('Authorization', autenticar())
      .send({ refreshToken: 'r1' });

    expect(res.status).toBe(200);
    expect(servicio.cerrarSesion).toHaveBeenCalledWith(usuarioId, 'r1', RolUsuario.ESTUDIANTE);
  });
});
