import { Prisma } from '../../../generated/prisma/client';
import { prisma, type ClientePrisma } from '../../../configuracion/prisma';
import { EstadoSolicitudGuardia } from './estado-solicitud-guardia';
import { TipoSolicitudGuardia } from './tipo-solicitud-guardia';
import { bloquearFila } from '../../../comun/utilidades/bloqueos';

export const includeSolicitudCompleta = {
  solicitadaPorUsuario: true,
  bicicletero: true,
  guardiaAsignado: true
} satisfies Prisma.SolicitudGuardiaInclude;

export type SolicitudCompleta = Prisma.SolicitudGuardiaGetPayload<{
  include: typeof includeSolicitudCompleta;
}>;

export const ejecutarEnTransaccion = <T>(callback: (client: ClientePrisma) => Promise<T>) =>
  prisma.$transaction(callback);

export const buscarBicicletero = (id: string, client: ClientePrisma = prisma) =>
  client.bicicletero.findUnique({
    where: { id }
  });

export const buscarSolicitudAbierta = (
  params: {
    usuarioId: string;
    bicicleteroId: string;
    tipo: TipoSolicitudGuardia;
    estadosCerrados: EstadoSolicitudGuardia[];
  },
  client: ClientePrisma = prisma
) =>
  client.solicitudGuardia.findFirst({
    where: {
      solicitadaPorUsuarioId: params.usuarioId,
      bicicleteroId: params.bicicleteroId,
      tipo: params.tipo,
      estado: {
        notIn: params.estadosCerrados
      }
    },
    include: includeSolicitudCompleta,
    orderBy: {
      creadaEn: 'desc'
    }
  });

export const buscarAsignacionActivaConGuardia = (
  bicicleteroId: string,
  client: ClientePrisma = prisma
) =>
  client.asignacionGuardia.findFirst({
    where: {
      bicicleteroId,
      activa: true
    },
    include: {
      guardia: true
    },
    orderBy: {
      iniciaEn: 'desc'
    }
  });

export const crear = (
  data: Prisma.SolicitudGuardiaUncheckedCreateInput,
  client: ClientePrisma = prisma
) => client.solicitudGuardia.create({ data, include: includeSolicitudCompleta });

export const buscarPorId = async (id: string, client: ClientePrisma = prisma) => {
  if (client !== prisma) await bloquearFila(client, 'solicitudes_guardia', id);
  return client.solicitudGuardia.findUnique({
    where: { id },
    include: includeSolicitudCompleta
  });
};

export const buscarPorIdOError = (id: string, client: ClientePrisma = prisma) =>
  client.solicitudGuardia.findUniqueOrThrow({
    where: { id },
    include: includeSolicitudCompleta
  });

export const actualizar = (
  id: string,
  data: Prisma.SolicitudGuardiaUpdateInput,
  client: ClientePrisma = prisma
) =>
  client.solicitudGuardia.update({
    where: { id },
    data,
    include: includeSolicitudCompleta
  });

export const listar = (
  params: {
    where: Prisma.SolicitudGuardiaWhereInput;
    limite?: number;
  },
  client: ClientePrisma = prisma
) =>
  client.solicitudGuardia.findMany({
    where: params.where,
    include: includeSolicitudCompleta,
    orderBy: {
      creadaEn: 'desc'
    },
    ...(params.limite ? { take: params.limite } : {})
  });

export const listarSinAtenderDeBicicletero = (
  params: { bicicleteroId: string; guardiaId: string; estados: EstadoSolicitudGuardia[] },
  client: ClientePrisma = prisma
) =>
  client.solicitudGuardia.findMany({
    where: {
      bicicleteroId: params.bicicleteroId,
      estado: { in: params.estados },
      OR: [{ guardiaAsignadoId: null }, { guardiaAsignadoId: { not: params.guardiaId } }]
    },
    select: { id: true, solicitadaPorUsuarioId: true },
    orderBy: { creadaEn: 'asc' }
  });

export const asignarGuardia = (
  ids: string[],
  guardiaId: string,
  ahora: Date,
  client: ClientePrisma = prisma
) =>
  client.solicitudGuardia.updateMany({
    where: { id: { in: ids } },
    data: {
      guardiaAsignadoId: guardiaId,
      estado: EstadoSolicitudGuardia.NOTIFICADA,
      notificadaGuardiaEn: ahora,
      notificacionesGuardia: { increment: 1 }
    }
  });

export const listarSinRespuestaDeGuardia = (
  params: {
    guardiaId: string;
    estados: EstadoSolicitudGuardia[];
    exceptoBicicleteroId: string | null;
  },
  client: ClientePrisma = prisma
) =>
  client.solicitudGuardia.findMany({
    where: {
      guardiaAsignadoId: params.guardiaId,
      estado: { in: params.estados },
      ...(params.exceptoBicicleteroId
        ? { bicicleteroId: { not: params.exceptoBicicleteroId } }
        : {})
    },
    select: {
      id: true,
      solicitadaPorUsuarioId: true,
      bicicletero: { select: { id: true, nombre: true } },
      guardiaAsignado: { select: { nombre: true } }
    },
    orderBy: { creadaEn: 'asc' }
  });

export const dejarSinGuardia = (ids: string[], client: ClientePrisma = prisma) =>
  client.solicitudGuardia.updateMany({
    where: { id: { in: ids } },
    data: {
      guardiaAsignadoId: null,
      estado: EstadoSolicitudGuardia.PENDIENTE
    }
  });
