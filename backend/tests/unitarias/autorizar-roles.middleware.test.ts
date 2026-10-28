import '../apoyo/configurar-entorno';

import express from 'express';
import request from 'supertest';
import { SolicitudAutenticada } from '../../src/comun/middlewares/autenticacion.middleware';
import { autorizarRoles } from '../../src/comun/middlewares/autorizar-roles.middleware';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';

const crearApp = (rol: string | undefined, ...rolesPermitidos: string[]) => {
  const app = express();
  app.get(
    '/protegido',
    (req: SolicitudAutenticada, _res, next) => {
      if (rol) {
        req.usuario = { usuarioId: 'u1', rol, versionSesion: 1 };
      }
      next();
    },
    autorizarRoles(...rolesPermitidos),
    (_req, res) => res.status(200).json({ ok: true })
  );
  return app;
};

describe('autorizarRoles', () => {
  it('deja pasar a un rol permitido', async () => {
    const res = await request(crearApp(RolUsuario.GUARDIA, RolUsuario.GUARDIA)).get('/protegido');

    expect(res.status).toBe(200);
  });

  it('acepta cualquiera de varios roles permitidos', async () => {
    const res = await request(
      crearApp(RolUsuario.FUNCIONARIO, RolUsuario.ESTUDIANTE, RolUsuario.FUNCIONARIO)
    ).get('/protegido');

    expect(res.status).toBe(200);
  });

  it('el administrador siempre tiene acceso', async () => {
    const res = await request(crearApp(RolUsuario.ADMINISTRADOR, RolUsuario.GUARDIA)).get(
      '/protegido'
    );

    expect(res.status).toBe(200);
  });

  it('rechaza con 403 un rol no permitido', async () => {
    const res = await request(crearApp(RolUsuario.ESTUDIANTE, RolUsuario.GUARDIA)).get(
      '/protegido'
    );

    expect(res.status).toBe(403);
    expect(res.body.message).toBe('No tienes permisos para realizar esta acción');
  });

  it('rechaza con 403 si la solicitud no trae usuario', async () => {
    const res = await request(crearApp(undefined, RolUsuario.GUARDIA)).get('/protegido');

    expect(res.status).toBe(403);
  });
});
