import '../helpers/env-setup';

jest.mock('../../src/configuracion/redis', () => ({
  obtenerClienteRedis: jest.fn().mockResolvedValue(null)
}));

import type { NextFunction, Request, Response } from 'express';
import { limitarIntentos } from '../../src/comun/middlewares/limitador-intentos.middleware';

type Terminar = () => void;

const crearRespuesta = () => {
  const oyentes: Terminar[] = [];
  return {
    statusCode: 200,
    cuerpo: undefined as unknown,
    cabeceras: {} as Record<string, string>,
    on(evento: string, oyente: Terminar) {
      if (evento === 'finish') oyentes.push(oyente);
      return this;
    },
    setHeader(nombre: string, valor: string) {
      this.cabeceras[nombre] = valor;
    },
    status(codigo: number) {
      this.statusCode = codigo;
      return this;
    },
    json(cuerpo: unknown) {
      this.cuerpo = cuerpo;
      return this;
    },
    terminar(codigo: number) {
      this.statusCode = codigo;
      for (const oyente of oyentes) oyente();
    }
  };
};

const ejecutar = async (
  middleware: ReturnType<typeof limitarIntentos>,
  correo: string,
  codigoFinal: number
) => {
  const req = { ip: '10.0.0.1', path: '/login', body: { correo } } as unknown as Request;
  const res = crearRespuesta();
  const siguiente = jest.fn();

  await middleware(req, res as unknown as Response, siguiente as unknown as NextFunction);

  const pasó = siguiente.mock.calls.length > 0;
  if (pasó) res.terminar(codigoFinal);

  return { pasó, res };
};

const opcionesLogin = {
  ventanaMs: 60_000,
  maximo: 3,
  mensaje: 'Demasiados intentos fallidos para esta cuenta. Intenta más tarde.',
  contarSoloFallos: true,
  clave: (req: Request) => `login:${String(req.body?.correo ?? '').toLowerCase()}`
};

describe('limitador de intentos de ingreso', () => {
  it('los ingresos correctos no gastan el cupo', async () => {
    const middleware = limitarIntentos(opcionesLogin);

    for (let i = 0; i < 10; i++) {
      const { pasó } = await ejecutar(middleware, 'ok@ubiobio.cl', 200);
      expect(pasó).toBe(true);
    }
  });

  it('bloquea recien despues de agotar los intentos fallidos', async () => {
    const middleware = limitarIntentos(opcionesLogin);

    for (let i = 0; i < 3; i++) {
      const { pasó } = await ejecutar(middleware, 'falla@ubiobio.cl', 401);
      expect(pasó).toBe(true);
    }

    const { pasó, res } = await ejecutar(middleware, 'falla@ubiobio.cl', 401);
    expect(pasó).toBe(false);
    expect(res.statusCode).toBe(429);
    expect(res.cabeceras['Retry-After']).toBeDefined();
  });

  it('el bloqueo de una cuenta no afecta a las demas', async () => {
    const middleware = limitarIntentos(opcionesLogin);

    for (let i = 0; i < 4; i++) {
      await ejecutar(middleware, 'bloqueada@ubiobio.cl', 401);
    }

    const bloqueada = await ejecutar(middleware, 'bloqueada@ubiobio.cl', 401);
    expect(bloqueada.pasó).toBe(false);

    const otra = await ejecutar(middleware, 'otra@ubiobio.cl', 200);
    expect(otra.pasó).toBe(true);
  });

  it('sin contarSoloFallos se cuenta cada peticion', async () => {
    const middleware = limitarIntentos({
      ventanaMs: 60_000,
      maximo: 2,
      mensaje: 'Demasiados registros desde este origen. Intenta más tarde.'
    });

    expect((await ejecutar(middleware, 'a@ubiobio.cl', 200)).pasó).toBe(true);
    expect((await ejecutar(middleware, 'a@ubiobio.cl', 200)).pasó).toBe(true);
    expect((await ejecutar(middleware, 'a@ubiobio.cl', 200)).pasó).toBe(false);
  });
});
