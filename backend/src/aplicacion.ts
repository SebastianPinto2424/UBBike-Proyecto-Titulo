import cors from 'cors';
import { conTiempoLimite } from './comun/utilidades/tiempo-limite';
import helmet from 'helmet';
import express, { Request, Response } from 'express';
import swaggerUi from 'swagger-ui-express';
import { middlewareErrores } from './comun/middlewares/errores.middleware';
import { entorno } from './configuracion/entorno';
import { prisma } from './configuracion/prisma';
import { obtenerClienteRedis } from './configuracion/redis';
import { especificacionSwagger } from './configuracion/swagger';
import { registrarRutasModulos } from './modulos/rutas';

const aplicacion = express();

aplicacion.set('trust proxy', entorno.servidor.trustProxy);
aplicacion.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
aplicacion.use(
  cors({
    origin: (origen, callback) => {
      if (!origen || entorno.cors.origenes.includes(origen)) {
        return callback(null, true);
      }

      return callback(null, false);
    }
  })
);
aplicacion.use(express.json({ limit: '8mb' }));
aplicacion.use(
  entorno.archivos.rutaPublicaUploads,
  express.static(entorno.archivos.directorioUploads, {
    index: false,
    fallthrough: false,
    maxAge: '7d'
  })
);

if (entorno.swagger.habilitado) {
  aplicacion.use(
    '/docs',
    swaggerUi.serve,
    swaggerUi.setup(especificacionSwagger, {
      customSiteTitle: 'UBBike API Docs',
      swaggerOptions: { persistAuthorization: true }
    })
  );

  aplicacion.get('/docs.json', (_req: Request, res: Response) => {
    return res.json(especificacionSwagger);
  });
}

aplicacion.get(['/salud', '/health'], async (_req: Request, res: Response) => {
  const dependencias = { baseDatos: false, redis: false };

  try {
    await conTiempoLimite(prisma.$queryRaw`SELECT 1`);
    dependencias.baseDatos = true;
  } catch {
    dependencias.baseDatos = false;
  }

  if (entorno.redis.url) {
    try {
      dependencias.redis = await conTiempoLimite(
        (async () => {
          const redis = await obtenerClienteRedis();
          return redis != null && (await redis.ping()) === 'PONG';
        })()
      );
    } catch {
      dependencias.redis = false;
    }
  } else {
    dependencias.redis = entorno.ambiente !== 'production';
  }

  const operativo = dependencias.baseDatos && dependencias.redis;

  return res.status(operativo ? 200 : 503).json({
    status: operativo ? 'ok' : 'degradado',
    message: operativo
      ? 'UBBike backend funcionando'
      : 'UBBike backend con dependencias no disponibles',
    dependencias
  });
});

registrarRutasModulos(aplicacion);
aplicacion.use(middlewareErrores);

export { aplicacion };
