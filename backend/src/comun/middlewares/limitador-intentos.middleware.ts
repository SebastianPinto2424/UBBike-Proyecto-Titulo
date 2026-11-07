import { createHash } from 'crypto';
import { NextFunction, Request, Response } from 'express';
import { entorno } from '../../configuracion/entorno';
import { obtenerClienteRedis } from '../../configuracion/redis';
import type { SolicitudAutenticada } from './autenticacion.middleware';

export const quinceMinutos = 15 * 60 * 1000;

export const porCampoDelCuerpo = (prefijo: string, campo: string) => (req: Request) =>
  `${prefijo}:${String(req.body?.[campo] ?? '')
    .trim()
    .toLowerCase()}`;

export const porHuellaDelCampo = (prefijo: string, campo: string) => (req: Request) =>
  `${prefijo}:${createHash('sha256')
    .update(String(req.body?.[campo] ?? ''))
    .digest('hex')
    .slice(0, 32)}`;

export const porUsuarioAutenticado = (prefijo: string) => (req: Request) =>
  `${prefijo}:${(req as SolicitudAutenticada).usuario?.usuarioId ?? ''}`;

type OpcionesLimitador = {
  ventanaMs: number;
  maximo: number;
  mensaje: string;

  contarSoloFallos?: boolean;

  clave?: (req: Request) => string;

  alBloquear?: (res: Response, mensaje: string) => Response;
};

type RegistroIntentos = {
  cantidad: number;
  reiniciaEn: number;
};

const intentos = new Map<string, RegistroIntentos>();

const leerEnMemoria = (clave: string, ahora: number) => {
  const registro = intentos.get(clave);
  if (!registro || registro.reiniciaEn <= ahora) {
    return { cantidad: 0, reiniciaEn: 0 };
  }
  return registro;
};

const sumarEnMemoria = (clave: string, ventanaMs: number, ahora: number) => {
  const registro = intentos.get(clave);
  if (!registro || registro.reiniciaEn <= ahora) {
    intentos.set(clave, { cantidad: 1, reiniciaEn: ahora + ventanaMs });
    return;
  }
  registro.cantidad += 1;
  intentos.set(clave, registro);
};

const responderBloqueo = (res: Response, opciones: OpcionesLimitador, segundos: number) => {
  res.setHeader('Retry-After', Math.max(segundos, 1).toString());
  return opciones.alBloquear
    ? opciones.alBloquear(res, opciones.mensaje)
    : res.status(429).json({ message: opciones.mensaje });
};

export const ajustarMaximo = (maximo: number): number =>
  Math.max(1, Math.round(maximo * entorno.limitadorIntentos.factor));

export const limitarIntentos =
  (opciones: OpcionesLimitador) => async (req: Request, res: Response, next: NextFunction) => {
    const ahora = Date.now();
    const identificador = opciones.clave ? opciones.clave(req) : req.ip;
    const clave = `${identificador}:${req.path}`;
    const claveRedis = `rate-limit:${clave}`;

    let redis: Awaited<ReturnType<typeof obtenerClienteRedis>> = null;

    try {
      redis = await obtenerClienteRedis();
    } catch (error) {
      console.error('No se pudo aplicar rate limiting distribuido', error);

      if (entorno.redis.requerirParaLimitador) {
        return res.status(503).json({
          message: 'Protección temporal no disponible. Intenta nuevamente más tarde.'
        });
      }
    }

    const sumar = async () => {
      if (redis) {
        const cantidad = await redis.incr(claveRedis);
        if (cantidad === 1) {
          await redis.pExpire(claveRedis, opciones.ventanaMs);
        }
        return;
      }
      sumarEnMemoria(clave, opciones.ventanaMs, ahora);
    };

    const cantidadActual = redis
      ? Number((await redis.get(claveRedis)) ?? 0)
      : leerEnMemoria(clave, ahora).cantidad;

    if (cantidadActual >= opciones.maximo) {
      const segundos = redis
        ? Math.ceil((await redis.pTTL(claveRedis)) / 1000)
        : Math.ceil((leerEnMemoria(clave, ahora).reiniciaEn - ahora) / 1000);
      return responderBloqueo(res, opciones, segundos);
    }

    if (!opciones.contarSoloFallos) {
      await sumar();
      return next();
    }

    res.on('finish', () => {
      if (res.statusCode >= 400) {
        void sumar();
      }
    });

    return next();
  };
