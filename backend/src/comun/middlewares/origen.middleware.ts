import type { NextFunction, Request, Response } from 'express';
import { origenPermitido } from '../utilidades/origenes';

const paginasDeNavegador = ['/enlaces/'];

export const restringirOrigen = (req: Request, res: Response, next: NextFunction) => {
  if (
    paginasDeNavegador.some((ruta) => req.path.startsWith(ruta)) ||
    origenPermitido(req.headers.origin, req.headers.host)
  ) {
    return next();
  }

  return res.status(403).json({ message: 'Origen no permitido' });
};
