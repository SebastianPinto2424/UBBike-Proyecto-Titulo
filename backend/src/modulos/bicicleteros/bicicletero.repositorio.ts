import { Prisma } from '../../generated/prisma/client';
import { prisma, type ClientePrisma } from '../../configuracion/prisma';

const filtroOcupacion = {
  dentroBicicletero: true,
  eliminadoEn: null
} as const;

export const listarActivos = (client: ClientePrisma = prisma) =>
  client.bicicletero.findMany({
    where: { activo: true },
    orderBy: { nombre: 'asc' }
  });

export const crear = (
  data: Prisma.BicicleteroUncheckedCreateInput,
  client: ClientePrisma = prisma
) => client.bicicletero.create({ data });

export const buscarPorId = (id: string, client: ClientePrisma = prisma) =>
  client.bicicletero.findUnique({ where: { id } });

export const buscarPorNombre = (nombre: string, client: ClientePrisma = prisma) =>
  client.bicicletero.findUnique({ where: { nombre } });

export const actualizar = (
  id: string,
  data: Prisma.BicicleteroUpdateInput,
  client: ClientePrisma = prisma
) => client.bicicletero.update({ where: { id }, data });

export const contarOcupadosAgrupados = (client: ClientePrisma = prisma) =>
  client.bicicleta.groupBy({
    by: ['bicicleteroActualId'],
    where: { ...filtroOcupacion, bicicleteroActualId: { not: null } },
    _count: { _all: true }
  });

export const contarOcupados = (bicicleteroId: string, client: ClientePrisma = prisma) =>
  client.bicicleta.count({
    where: { ...filtroOcupacion, bicicleteroActualId: bicicleteroId }
  });
