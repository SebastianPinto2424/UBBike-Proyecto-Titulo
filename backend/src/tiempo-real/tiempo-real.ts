import type { Server as ServidorHttp } from 'http';
import jwt from 'jsonwebtoken';
import { Server, type Socket } from 'socket.io';
import { entorno } from '../configuracion/entorno';
import { prisma } from '../configuracion/prisma';

type CargaToken = {
  usuarioId: string;
  rol: string;
  versionSesion: number;
  exp: number;
};

const INTERVALO_REVALIDACION_MS = 5 * 60 * 1000;

const sesionSigueValida = async (usuarioId: string, versionSesion: number): Promise<boolean> => {
  const usuario = await prisma.usuario.findUnique({ where: { id: usuarioId } });

  return Boolean(
    usuario &&
    usuario.cuentaActiva &&
    usuario.correoVerificado &&
    usuario.versionSesion === versionSesion
  );
};

export const EventosTiempoReal = {
  NOTIFICACION: 'notificacion',
  MOVIMIENTO: 'movimiento',
  SOLICITUD: 'solicitud',
  INCIDENCIA: 'incidencia',
  USUARIO: 'usuario'
} as const;

export const salaUsuario = (usuarioId: string) => `usuario:${usuarioId}`;
export const salaRol = (rol: string) => `rol:${rol}`;

let io: Server | null = null;

export const inicializarTiempoReal = (servidor: ServidorHttp): Server => {
  io = new Server(servidor, {
    cors: {
      origin: entorno.cors.origenes,
      credentials: false
    }
  });

  io.use(async (socket, next) => {
    const token = (socket.handshake.auth?.token as string | undefined) ?? '';

    if (!token) {
      return next(new Error('Token de tiempo real requerido'));
    }

    try {
      const carga = jwt.verify(token, entorno.jwt.secreto, {
        algorithms: ['HS256'],
        audience: entorno.jwt.audiencia,
        issuer: entorno.jwt.emisor
      }) as CargaToken;

      if (!(await sesionSigueValida(carga.usuarioId, carga.versionSesion))) {
        return next(new Error('La sesión fue invalidada. Inicia sesión nuevamente.'));
      }

      socket.data.usuarioId = carga.usuarioId;
      socket.data.rol = carga.rol;
      socket.data.versionSesion = carga.versionSesion;
      if (!Number.isFinite(carga.exp)) return next(new Error('Token sin expiración'));
      socket.data.exp = carga.exp;
      return next();
    } catch {
      return next(new Error('Token de tiempo real inválido'));
    }
  });

  io.on('connection', (socket: Socket) => {
    const usuarioId = socket.data.usuarioId as string;
    const rol = socket.data.rol as string;
    const versionSesion = socket.data.versionSesion as number;
    socket.join(salaUsuario(usuarioId));
    socket.join(salaRol(rol));

    const expiracion = setTimeout(
      () => socket.disconnect(true),
      Math.max(0, Math.min(socket.data.exp * 1000 - Date.now(), 2147483647))
    );
    const intervalo = setInterval(async () => {
      try {
        if (!(await sesionSigueValida(usuarioId, versionSesion))) socket.disconnect(true);
      } catch {
        console.error('[tiempo-real] No se pudo revalidar la sesión');
        socket.disconnect(true);
      }
    }, INTERVALO_REVALIDACION_MS);

    socket.on('disconnect', () => {
      clearInterval(intervalo);
      clearTimeout(expiracion);
    });
  });

  return io;
};

export const emitirTiempoReal = (salas: string[], evento: string, payload?: unknown): void => {
  if (!io || salas.length === 0) {
    return;
  }

  io.to([...new Set(salas)]).emit(evento, payload ?? {});
};
