import { Prisma } from '../../generated/prisma/client';
import { prisma, type ClientePrisma } from '../../configuracion/prisma';
import type { RolUsuario } from '../usuarios/rol-usuario';
import { bloquearFila } from '../../comun/utils/bloqueos';

export const includeIncidenciaCompleta = {
  reportadaPorUsuario: true,
  gestionadaPorUsuario: true,
  bicicletero: true,
  bicicleta: true
} satisfies Prisma.IncidenciaInclude;

export type IncidenciaCompleta = Prisma.IncidenciaGetPayload<{
  include: typeof includeIncidenciaCompleta;
}>;

export const ejecutarEnTransaccion = <T>(callback: (client: ClientePrisma) => Promise<T>) =>
  prisma.$transaction(callback);

export const buscarBicicleterosAsignados = (guardiaId: string, client: ClientePrisma = prisma) =>
  client.asignacionGuardia.findMany({
    where: { guardiaId, activa: true },
    select: { bicicleteroId: true }
  });

export const buscarBicicletero = (id: string, client: ClientePrisma = prisma) =>
  client.bicicletero.findUnique({ where: { id } });

export const buscarBicicletaActiva = (id: string, client: ClientePrisma = prisma) =>
  client.bicicleta.findFirst({ where: { id, eliminadoEn: null } });

export const crear = (
  data: Prisma.IncidenciaUncheckedCreateInput,
  client: ClientePrisma = prisma
) => client.incidencia.create({ data, include: includeIncidenciaCompleta });

export const buscarUsuariosPorRoles = (roles: RolUsuario[], client: ClientePrisma = prisma) =>
  client.usuario.findMany({
    where: { rol: { in: roles }, cuentaActiva: true, eliminadoEn: null },
    select: { id: true, nombre: true, correo: true }
  });

export const listar = (
  params: { where: Prisma.IncidenciaWhereInput; take: number; cursor?: string },
  client: ClientePrisma = prisma
) =>
  client.incidencia.findMany({
    where: params.where,
    include: includeIncidenciaCompleta,
    orderBy: [{ creadaEn: 'desc' }, { id: 'desc' }],
    take: params.take,
    ...(params.cursor ? { cursor: { id: params.cursor }, skip: 1 } : {})
  });

export const buscarPorId = async (id: string, client: ClientePrisma = prisma) => {
  if (client !== prisma) await bloquearFila(client, 'incidencias', id);
  return client.incidencia.findUnique({ where: { id }, include: includeIncidenciaCompleta });
};

export const actualizar = (
  id: string,
  data: Prisma.IncidenciaUncheckedUpdateInput,
  client: ClientePrisma = prisma
) => client.incidencia.update({ where: { id }, data, include: includeIncidenciaCompleta });
