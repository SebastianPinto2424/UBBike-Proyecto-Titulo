import { NextFunction, Request, RequestHandler, Response } from 'express';

type ManejadorAsync<TSolicitud extends Request = Request> = (
  req: TSolicitud,
  res: Response,
  next: NextFunction
) => Promise<unknown>;

export const controladorAsync =
  <TSolicitud extends Request = Request>(manejador: ManejadorAsync<TSolicitud>): RequestHandler =>
  (req, res, next) => {
    Promise.resolve(manejador(req as TSolicitud, res, next)).catch(next);
  };
