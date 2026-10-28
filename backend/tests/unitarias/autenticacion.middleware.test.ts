import '../apoyo/configurar-entorno';
import '../apoyo/prisma-simulado';
import { prismaSimulado } from '../apoyo/prisma-simulado';

import express from 'express';
import request from 'supertest';
import jwt from 'jsonwebtoken';
import {
  middlewareAutenticacion,
  middlewareAutenticacionSinExigirCambio
} from '../../src/comun/middlewares/autenticacion.middleware';

jest.mock('jsonwebtoken');
const jwtMock = jwt as jest.Mocked<typeof jwt>;

const usuarioBase = {
  id: 'u1',
  rol: 'ESTUDIANTE',
  versionSesion: 1,
  cuentaActiva: true,
  correoVerificado: true,
  debeCambiarContrasena: false
};

const crearApp = (middleware: express.RequestHandler) => {
  const app = express();
  app.get('/protegido', middleware, (_req, res) => res.status(200).json({ ok: true }));
  return app;
};

beforeEach(() => {
  jwtMock.verify.mockReturnValue({
    usuarioId: 'u1',
    rol: 'ESTUDIANTE',
    versionSesion: 1
  } as never);
});

describe('middlewareAutenticacion · contraseña temporal pendiente', () => {
  it('bloquea con 403 cuando debeCambiarContrasena es true', async () => {
    prismaSimulado.usuario.findUnique.mockResolvedValue({
      ...usuarioBase,
      debeCambiarContrasena: true
    } as never);

    const res = await request(crearApp(middlewareAutenticacion))
      .get('/protegido')
      .set('Authorization', 'Bearer token');

    expect(res.status).toBe(403);
    expect(res.body.codigo).toBe('CAMBIO_CONTRASENA_REQUERIDO');
  });

  it('permite el acceso cuando no hay cambio pendiente', async () => {
    prismaSimulado.usuario.findUnique.mockResolvedValue(usuarioBase as never);

    const res = await request(crearApp(middlewareAutenticacion))
      .get('/protegido')
      .set('Authorization', 'Bearer token');

    expect(res.status).toBe(200);
  });

  it('la variante permisiva deja pasar aunque haya cambio pendiente', async () => {
    prismaSimulado.usuario.findUnique.mockResolvedValue({
      ...usuarioBase,
      debeCambiarContrasena: true
    } as never);

    const res = await request(crearApp(middlewareAutenticacionSinExigirCambio))
      .get('/protegido')
      .set('Authorization', 'Bearer token');

    expect(res.status).toBe(200);
  });
});
