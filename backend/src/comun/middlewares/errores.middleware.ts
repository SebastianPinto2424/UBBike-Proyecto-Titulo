import { ErrorRequestHandler } from 'express';
import { Prisma } from '../../generated/prisma/client';
import { ErrorHttp } from '../errores/error-http';

type ErrorJsonMalformado = SyntaxError & {
  status?: number;
  type?: string;
};

const esErrorJsonMalformado = (error: unknown): error is ErrorJsonMalformado =>
  error instanceof SyntaxError &&
  (error as ErrorJsonMalformado).status === 400 &&
  (error as ErrorJsonMalformado).type === 'entity.parse.failed';

export const middlewareErrores: ErrorRequestHandler = (error, _req, res, _next) => {
  if (error instanceof ErrorHttp) {
    return res.status(error.statusCode).json({
      message: error.message,
      ...(error.codigo ? { codigo: error.codigo } : {})
    });
  }

  if (esErrorJsonMalformado(error)) {
    return res.status(400).json({
      message: 'El cuerpo JSON no es válido.'
    });
  }

  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    if (error.code === 'P2002') {
      return res.status(409).json({
        message:
          'Ya existe un registro con esos datos. Revisa los campos únicos (correo, RUT, etc.).'
      });
    }

    if (error.code === 'P2025') {
      return res.status(404).json({
        message: 'El recurso solicitado no existe.'
      });
    }
  }

  console.error(error);

  return res.status(500).json({
    message: 'Error interno del servidor'
  });
};
