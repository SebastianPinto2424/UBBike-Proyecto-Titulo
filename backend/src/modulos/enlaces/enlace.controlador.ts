import type { NextFunction, Request, Response } from 'express';
import { esAccionEnlace, esResultadoEnlace, type AccionEnlace } from './enlace.servicio';
import {
  procesarEnlace,
  reenviarConEnlace,
  revisarEnlace,
  type ProcesoEnlace
} from './formulario-enlace.servicio';
import { paginaError, paginaFormulario, paginaResultado } from './enlace.vistas';

const politicaContenido = [
  "default-src 'none'",
  "img-src 'self'",
  "script-src 'self'",
  "style-src 'unsafe-inline'",
  "form-action 'self'",
  "base-uri 'none'",
  "frame-ancestors 'none'"
].join('; ');

const enviarPagina = (res: Response, estado: number, html: string) =>
  res.status(estado).type('html').send(html);

const paginaNoEncontrada = () =>
  paginaError(
    'Enlace no válido',
    'Este enlace no es válido o está incompleto. Vuelve a abrir el correo o solicita uno nuevo desde la app.'
  );

const responderFallo = (res: Response, error: unknown) => {
  console.error('[enlaces] No se pudo atender el enlace', error);
  return enviarPagina(
    res,
    500,
    paginaError(
      'No pudimos completar la solicitud',
      'Ocurrió un problema de nuestro lado. Intenta nuevamente en unos minutos.'
    )
  );
};

export const prepararRespuestaEnlace = (_req: Request, res: Response, next: NextFunction) => {
  res.set({ 'Cache-Control': 'no-store', 'Content-Security-Policy': politicaContenido });
  next();
};

export const responderBloqueoEnlace = (res: Response, mensaje: string) =>
  enviarPagina(res, 429, paginaError('Demasiados intentos', mensaje));

export const mostrarFormulario = async (req: Request, res: Response) => {
  const accion = req.params.accion;
  if (!esAccionEnlace(accion)) {
    return enviarPagina(res, 404, paginaNoEncontrada());
  }

  const token = typeof req.query.token === 'string' ? req.query.token : '';

  try {
    const revision = await revisarEnlace(accion, token);
    return revision.valido
      ? enviarPagina(res, 200, paginaFormulario(accion, token, revision))
      : enviarPagina(
          res,
          400,
          paginaError(revision.titulo, revision.mensaje, revision.reenviable ? token : undefined)
        );
  } catch (error) {
    return responderFallo(res, error);
  }
};

const responderProceso = (res: Response, proceso: ProcesoEnlace, accion?: AccionEnlace) => {
  if (proceso.tipo === 'listo') {
    return res.redirect(303, `/enlaces/resultado/${proceso.resultado}`);
  }

  if (proceso.tipo === 'formulario' && accion) {
    return enviarPagina(
      res,
      400,
      paginaFormulario(accion, proceso.token, proceso.enlace, proceso.errores, proceso.nombre)
    );
  }

  return proceso.tipo === 'error'
    ? enviarPagina(
        res,
        proceso.estado,
        paginaError(proceso.titulo, proceso.mensaje, proceso.reenviarToken)
      )
    : enviarPagina(res, 404, paginaNoEncontrada());
};

export const procesarFormulario = async (req: Request, res: Response) => {
  const accion = req.params.accion;
  if (!esAccionEnlace(accion)) {
    return enviarPagina(res, 404, paginaNoEncontrada());
  }

  try {
    const proceso = await procesarEnlace(accion, (req.body ?? {}) as Record<string, unknown>);
    return responderProceso(res, proceso, accion);
  } catch (error) {
    return responderFallo(res, error);
  }
};

export const reenviarEnlace = async (req: Request, res: Response) => {
  const token = typeof req.body?.token === 'string' ? req.body.token : '';

  try {
    return responderProceso(res, await reenviarConEnlace(token));
  } catch (error) {
    return responderFallo(res, error);
  }
};

export const mostrarResultado = (req: Request, res: Response) => {
  const resultado = req.params.resultado;
  return esResultadoEnlace(resultado)
    ? enviarPagina(res, 200, paginaResultado(resultado))
    : enviarPagina(res, 404, paginaNoEncontrada());
};
