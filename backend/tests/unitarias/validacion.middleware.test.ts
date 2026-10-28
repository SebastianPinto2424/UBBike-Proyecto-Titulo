import express from 'express';
import Joi from 'joi';
import request from 'supertest';
import {
  validarConsulta,
  validarCuerpo,
  validarParametros
} from '../../src/comun/middlewares/validacion.middleware';
import { esquemaParametroId } from '../../src/comun/utilidades/esquemas-comunes';

const crearAppPrueba = () => {
  const app = express();
  app.use(express.json());
  app.post(
    '/validar',
    validarCuerpo(
      Joi.object({
        nombre: Joi.string().trim().min(3).required(),
        activo: Joi.boolean().default(false)
      })
    ),
    (req, res) => res.status(200).json({ body: req.body })
  );
  return app;
};

describe('validarCuerpo middleware · caja negra', () => {
  it('responde 400 y reporta todos los errores de validacion', async () => {
    const res = await request(crearAppPrueba()).post('/validar').send({
      nombre: 'ab',
      activo: 'no-es-booleano'
    });

    expect(res.status).toBe(400);
    expect(res.body.message).toBe('Datos inválidos');
    expect(res.body.details).toHaveLength(2);
  });

  it('normaliza el body valido, aplica defaults y elimina campos desconocidos', async () => {
    const res = await request(crearAppPrueba()).post('/validar').send({
      nombre: '  Usuario prueba  ',
      campoExtra: 'debe salir'
    });

    expect(res.status).toBe(200);
    expect(res.body.body).toEqual({
      nombre: 'Usuario prueba',
      activo: false
    });
  });
});

describe('validarParametros y validarConsulta middleware · caja negra', () => {
  const app = express();
  app.get('/recursos/:id', validarParametros(esquemaParametroId), (req, res) =>
    res.status(200).json({ id: req.params.id })
  );
  app.get(
    '/recursos',
    validarConsulta(
      Joi.object({
        limite: Joi.number().integer().min(1),
        activos: Joi.boolean()
      })
    ),
    (req, res) => res.status(200).json({ query: req.query })
  );

  it('responde 400 si el id de la ruta no es un UUID', async () => {
    const res = await request(app).get('/recursos/abc');

    expect(res.status).toBe(400);
    expect(res.body.details).toEqual(['Identificador inválido']);
  });

  it('deja pasar un id UUID valido', async () => {
    const id = '00000000-0000-4000-8000-000000000001';
    const res = await request(app).get(`/recursos/${id}`);

    expect(res.status).toBe(200);
    expect(res.body.id).toBe(id);
  });

  it('convierte los filtros validos y descarta los desconocidos', async () => {
    const res = await request(app).get('/recursos?limite=5&activos=true&extra=x');

    expect(res.status).toBe(200);
    expect(res.body.query).toEqual({ limite: 5, activos: true });
  });

  it('responde 400 con filtros de tipo incorrecto', async () => {
    const res = await request(app).get('/recursos?limite=cero&activos=quizas');

    expect(res.status).toBe(400);
    expect(res.body.details).toHaveLength(2);
  });
});
