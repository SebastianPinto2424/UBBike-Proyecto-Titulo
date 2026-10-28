import { Prisma } from '../../generated/prisma/client';
import { prisma, type ClientePrisma } from '../../configuracion/prisma';
import { RolUsuario } from '../usuarios/rol-usuario';
import type { TipoNotificacion } from './tipo-notificacion';

export const ejecutarEnTransaccion = <T>(callback: (client: ClientePrisma) => Promise<T>) =>
  prisma.$transaction(callback);

export const crear = (
  data: Prisma.NotificacionUncheckedCreateInput,
  client: ClientePrisma = prisma
) => client.notificacion.create({ data });

export const buscarIdsPorRoles = (
  roles: RolUsuario[],
  client: ClientePrisma = prisma,
  excluirUsuarioId?: string
) =>
  client.usuario.findMany({
    where: {
      rol: { in: roles },
      cuentaActiva: true,
      eliminadoEn: null,
      ...(excluirUsuarioId ? { id: { not: excluirUsuarioId } } : {})
    },
    select: { id: true }
  });

export const listarDeUsuario = (
  params: {
    usuarioId: string;
    soloNoLeidas: boolean;
    take: number;
    cursor?: string;
    tipos?: TipoNotificacion[];
  },
  client: ClientePrisma = prisma
) =>
  client.notificacion.findMany({
    where: {
      usuarioId: params.usuarioId,
      ...(params.tipos?.length ? { tipo: { in: params.tipos } } : {}),
      ...(params.soloNoLeidas ? { leida: false } : {})
    },
    orderBy: [{ creadaEn: 'desc' }, { id: 'desc' }],
    take: params.take,
    ...(params.cursor
      ? {
          cursor: { id: params.cursor },
          skip: 1
        }
      : {})
  });

export const contarNoLeidas = (
  usuarioId: string,
  tipos?: TipoNotificacion[],
  client: ClientePrisma = prisma
) =>
  client.notificacion.count({
    where: {
      usuarioId,
      leida: false,
      ...(tipos?.length ? { tipo: { in: tipos } } : {})
    }
  });

export const buscarDeUsuario = (usuarioId: string, id: string, client: ClientePrisma = prisma) =>
  client.notificacion.findFirst({ where: { id, usuarioId } });

export const marcarLeida = (id: string, client: ClientePrisma = prisma) =>
  client.notificacion.update({ where: { id }, data: { leida: true } });

export const marcarTodasLeidas = (
  usuarioId: string,
  tipos?: TipoNotificacion[],
  client: ClientePrisma = prisma
) =>
  client.notificacion.updateMany({
    where: {
      usuarioId,
      leida: false,
      ...(tipos?.length ? { tipo: { in: tipos } } : {})
    },
    data: { leida: true }
  });
