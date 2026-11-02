import '../apoyo/configurar-entorno';

const entornoOriginal = { ...process.env };

type ModuloOrigenes = typeof import('../../src/comun/utilidades/origenes');
type ModuloMiddleware = typeof import('../../src/comun/middlewares/origen.middleware');

const cargar = (variables: Record<string, string | undefined>) => {
  process.env = { ...entornoOriginal, ...variables };
  let origenes: ModuloOrigenes | undefined;
  let middleware: ModuloMiddleware | undefined;
  jest.isolateModules(() => {
    jest.doMock('dotenv', () => ({ config: jest.fn() }));
    origenes = require('../../src/comun/utilidades/origenes');
    middleware = require('../../src/comun/middlewares/origen.middleware');
  });
  return { ...origenes!, ...middleware! };
};

const crearApp = (restringirOrigen: ModuloMiddleware['restringirOrigen']) => {
  const express = require('express') as typeof import('express');
  const app = express();
  app.use(restringirOrigen);
  app.get('/recurso', (_req, res) => res.status(200).json({ ok: true }));
  app.post('/enlaces/verificar-correo', (_req, res) => res.status(200).json({ ok: true }));
  return app;
};

import request from 'supertest';

afterEach(() => {
  process.env = { ...entornoOriginal };
});

describe('origenes permitidos', () => {
  it('sin CORS_ORIGINS solo acepta el dominio publico del backend', () => {
    const { origenesNavegadorPermitidos } = cargar({
      CORS_ORIGINS: undefined,
      ENLACES_BASE_URL: 'https://ubbike.ejemplo.cl'
    });

    expect(origenesNavegadorPermitidos()).toEqual(['https://ubbike.ejemplo.cl']);
  });

  it('suma los origenes declarados en CORS_ORIGINS', () => {
    const { origenesNavegadorPermitidos } = cargar({
      CORS_ORIGINS: 'https://panel.ejemplo.cl, https://otro.ejemplo.cl',
      ENLACES_BASE_URL: 'https://ubbike.ejemplo.cl/'
    });

    expect(origenesNavegadorPermitidos()).toEqual([
      'https://panel.ejemplo.cl',
      'https://otro.ejemplo.cl',
      'https://ubbike.ejemplo.cl'
    ]);
  });

  it.each<[string | undefined, string | undefined, boolean]>([
    [undefined, undefined, true],
    ['https://ubbike.ejemplo.cl', undefined, true],
    ['https://panel.ejemplo.cl', undefined, true],
    ['https://otro-sitio.com', undefined, false],
    ['http://ubbike.ejemplo.cl', undefined, false],
    ['null', undefined, false],
    ['http://192.168.1.10:3000', '192.168.1.10:3000', true],
    ['https://otro-sitio.com', 'ubbike.ejemplo.cl', false]
  ])('origen %s con host %s: permitido=%p', (origen, host, esperado) => {
    const { origenPermitido } = cargar({
      CORS_ORIGINS: 'https://panel.ejemplo.cl',
      ENLACES_BASE_URL: 'https://ubbike.ejemplo.cl'
    });

    expect(origenPermitido(origen, host)).toBe(esperado);
  });
});

describe('restringirOrigen middleware · caja negra', () => {
  const variables = { CORS_ORIGINS: undefined, ENLACES_BASE_URL: 'https://ubbike.ejemplo.cl' };

  it('deja pasar a la app movil, que no envia Origin', async () => {
    const { restringirOrigen } = cargar(variables);

    const res = await request(crearApp(restringirOrigen)).get('/recurso');

    expect(res.status).toBe(200);
  });

  it('deja pasar al propio dominio, como las paginas de los enlaces', async () => {
    const { restringirOrigen } = cargar(variables);

    const res = await request(crearApp(restringirOrigen))
      .get('/recurso')
      .set('Origin', 'https://ubbike.ejemplo.cl');

    expect(res.status).toBe(200);
  });

  it('deja pasar el boton de las paginas de enlaces aunque el navegador envie Origin null', async () => {
    const { restringirOrigen } = cargar(variables);

    const res = await request(crearApp(restringirOrigen))
      .post('/enlaces/verificar-correo')
      .set('Origin', 'null');

    expect(res.status).toBe(200);
  });

  it('en la API un Origin null sigue rechazado', async () => {
    const { restringirOrigen } = cargar(variables);

    const res = await request(crearApp(restringirOrigen)).get('/recurso').set('Origin', 'null');

    expect(res.status).toBe(403);
  });

  it('rechaza con 403 a un sitio web ajeno', async () => {
    const { restringirOrigen } = cargar(variables);

    const res = await request(crearApp(restringirOrigen))
      .get('/recurso')
      .set('Origin', 'https://sitio-ajeno.com');

    expect(res.status).toBe(403);
    expect(res.body.message).toBe('Origen no permitido');
  });
});
