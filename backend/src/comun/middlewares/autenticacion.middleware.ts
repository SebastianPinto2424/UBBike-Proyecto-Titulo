import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { entorno } from '../../configuracion/entorno';
import { buscarPorId } from '../../modulos/autenticacion/autenticacion.repositorio';

export type CargaToken = {
  usuarioId: string;
  rol: string;
  versionSesion: number;
  debeCambiarContrasena?: boolean;
};

declare module 'express-serve-static-core' {
  interface Request {
    usuario?: CargaToken;
  }
}

export type SolicitudAutenticada = Request & {
  usuario?: CargaToken;
};

type OpcionesAutenticacion = {
  exigirContrasenaActualizada?: boolean;
};

const crearMiddlewareAutenticacion = ({
  exigirContrasenaActualizada = true
}: OpcionesAutenticacion = {}) => {
  return async (
    req: SolicitudAutenticada,
    res: Response,
    next: NextFunction
  ): Promise<Response | void> => {
    const autorizacion = req.headers.authorization;

    if (!autorizacion?.startsWith('Bearer ')) {
      return res.status(401).json({
        message: 'Token de autenticación requerido'
      });
    }

    const token = autorizacion.replace('Bearer ', '');

    try {
      const carga = jwt.verify(token, entorno.jwt.secreto, {
        algorithms: ['HS256'],
        audience: entorno.jwt.audiencia,
        issuer: entorno.jwt.emisor
      }) as CargaToken;

      const usuario = await buscarPorId(carga.usuarioId);

      if (!usuario || !usuario.cuentaActiva || !usuario.correoVerificado) {
        return res.status(401).json({
          message: 'Token de autenticación inválido o expirado'
        });
      }

      if (usuario.versionSesion !== carga.versionSesion) {
        return res.status(401).json({
          message: 'La sesión fue invalidada. Inicia sesión nuevamente.'
        });
      }

      if (exigirContrasenaActualizada && usuario.debeCambiarContrasena) {
        return res.status(403).json({
          message: 'Debes cambiar tu contraseña temporal antes de continuar.',
          codigo: 'CAMBIO_CONTRASENA_REQUERIDO'
        });
      }

      req.usuario = {
        usuarioId: usuario.id,
        rol: usuario.rol,
        versionSesion: usuario.versionSesion,
        debeCambiarContrasena: usuario.debeCambiarContrasena
      };
      return next();
    } catch {
      return res.status(401).json({
        message: 'Token de autenticación inválido o expirado'
      });
    }
  };
};

export const middlewareAutenticacion = crearMiddlewareAutenticacion();

export const middlewareAutenticacionSinExigirCambio = crearMiddlewareAutenticacion({
  exigirContrasenaActualizada: false
});
