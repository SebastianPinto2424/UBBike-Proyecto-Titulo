import { NextFunction, Request, Response } from 'express';
import { ObjectSchema } from 'joi';

type OrigenDatos = 'body' | 'params' | 'query';

const validar =
  (origen: OrigenDatos, esquema: ObjectSchema) =>
  (req: Request, res: Response, next: NextFunction) => {
    const { error, value } = esquema.validate(req[origen], {
      abortEarly: false,
      stripUnknown: true
    });

    if (error) {
      return res.status(400).json({
        message: 'Datos inválidos',
        details: error.details.map((detail) => detail.message)
      });
    }

    req[origen] = value;
    return next();
  };

export const validarCuerpo = (esquema: ObjectSchema) => validar('body', esquema);

export const validarParametros = (esquema: ObjectSchema) => validar('params', esquema);

export const validarConsulta = (esquema: ObjectSchema) => validar('query', esquema);
