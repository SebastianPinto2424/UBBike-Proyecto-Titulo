import type { Request, Response } from 'express';
import { middlewareErrores } from '../../src/comun/middlewares/errores.middleware';
import { ErrorHttp } from '../../src/comun/errores/error-http';
import { Prisma } from '../../src/generated/prisma/client';

const crearRes = () => {
  const res = {} as Response & { status: jest.Mock; json: jest.Mock };
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
};

const req = {} as Request;
const next = jest.fn();

describe('middlewareErrores', () => {
  it('respeta el statusCode de un ErrorHttp', () => {
    const res = crearRes();
    middlewareErrores(new ErrorHttp(400, 'dato inválido'), req, res, next);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ message: 'dato inválido' });
  });

  it('incluye el código del error cuando la app debe distinguirlo', () => {
    const res = crearRes();
    middlewareErrores(
      new ErrorHttp(403, 'Aún no confirmas tu correo.', 'CORREO_NO_VERIFICADO'),
      req,
      res,
      next
    );
    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({
      message: 'Aún no confirmas tu correo.',
      codigo: 'CORREO_NO_VERIFICADO'
    });
  });

  it('mapea P2002 (restricción única) a 409', () => {
    const res = crearRes();
    const error = new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
      code: 'P2002',
      clientVersion: 'test'
    });
    middlewareErrores(error, req, res, next);
    expect(res.status).toHaveBeenCalledWith(409);
  });

  it('mapea P2025 (registro no encontrado) a 404', () => {
    const res = crearRes();
    const error = new Prisma.PrismaClientKnownRequestError('Record not found', {
      code: 'P2025',
      clientVersion: 'test'
    });
    middlewareErrores(error, req, res, next);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('cae en 500 genérico para errores desconocidos', () => {
    const res = crearRes();
    const spy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    middlewareErrores(new Error('algo raro'), req, res, next);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({ message: 'Error interno del servidor' });
    spy.mockRestore();
  });
});
