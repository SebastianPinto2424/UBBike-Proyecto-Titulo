import '../apoyo/configurar-entorno';

jest.mock('../apoyo/prisma-simulado');

jest.mock('../../src/configuracion/redis', () => ({
  obtenerClienteRedis: jest.fn().mockResolvedValue(null)
}));

jest.mock('../../src/modulos/correos/cuenta.plantillas', () => ({
  crearCorreoVerificacion: jest.fn().mockReturnValue({ asunto: '', texto: '', html: '' })
}));

jest.mock('../../src/modulos/correos/correo.servicio', () => ({
  enviarCorreo: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/notificaciones/notificacion.servicio', () => ({
  crearNotificacion: jest.fn().mockResolvedValue(undefined),
  notificarUsuariosPorRol: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/auditoria/auditoria.servicio', () => ({
  registrarAuditoria: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/configuracion/prisma', () => ({
  prisma: {
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    usuario: {
      findUnique: jest.fn().mockResolvedValue(null),
      findFirst: jest.fn().mockResolvedValue(null),
      create: jest.fn(),
      update: jest.fn()
    }
  }
}));

import request from 'supertest';
import { aplicacion } from '../../src/aplicacion';

describe('POST /autenticacion/login', () => {
  it('responde 400 si no se envia body', async () => {
    const res = await request(aplicacion).post('/autenticacion/login').send({});
    expect(res.status).toBe(400);
  });

  it('responde 400 si falta contrasena', async () => {
    const res = await request(aplicacion)
      .post('/autenticacion/login')
      .send({ correo: 'juan@alumnos.ubiobio.cl' });
    expect(res.status).toBe(400);
  });

  it('responde 401 con credenciales invalidas (usuario no existe)', async () => {
    const res = await request(aplicacion)
      .post('/autenticacion/login')
      .send({ correo: 'noexiste@alumnos.ubiobio.cl', contrasena: 'cualquier' });
    expect(res.status).toBe(401);
  });
});

describe('POST /autenticacion/reenviar-verificacion', () => {
  it('responde lo mismo exista o no una cuenta pendiente', async () => {
    const res = await request(aplicacion)
      .post('/autenticacion/reenviar-verificacion')
      .send({ correo: 'Nadie@Alumnos.ubiobio.cl' });

    expect(res.status).toBe(200);
    expect(res.body.message).toBe(
      'Si hay una cuenta pendiente de confirmar con ese correo, te enviamos un enlace nuevo.'
    );
  });

  it('responde 400 si el correo no es válido', async () => {
    const res = await request(aplicacion)
      .post('/autenticacion/reenviar-verificacion')
      .send({ correo: 'no-es-correo' });

    expect(res.status).toBe(400);
  });
});

describe('POST /autenticacion/refresh', () => {
  it('responde 400 si no se envia refreshToken', async () => {
    const res = await request(aplicacion)
      .post('/autenticacion/refresh')
      .send({ usuarioId: 'uuid-cualquiera' });
    expect(res.status).toBe(400);
  });

  it('responde 400 si usuarioId no es uuid', async () => {
    const res = await request(aplicacion)
      .post('/autenticacion/refresh')
      .send({ usuarioId: 'no-es-uuid', refreshToken: 'token-cualquiera' });
    expect(res.status).toBe(400);
  });
});

describe('POST /autenticacion/logout', () => {
  it('responde 401 si no se envia token JWT', async () => {
    const res = await request(aplicacion).post('/autenticacion/logout').send({});
    expect(res.status).toBe(401);
  });
});

describe('GET /health', () => {
  it('responde 200 con status ok', async () => {
    const res = await request(aplicacion).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});
