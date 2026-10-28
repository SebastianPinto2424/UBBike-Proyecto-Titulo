import { Prisma } from '../../generated/prisma/client';
import { prisma, type ClientePrisma } from '../../configuracion/prisma';

const filtroOcupacion = {
  dentroBicicletero: true,
  eliminadoEn: null
} as const;

export const ejecutarEnTransaccion = <T>(callback: (client: ClientePrisma) => Promise<T>) =>
  prisma.$transaction(callback);

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

export const listarGuardiasActivos = (client: ClientePrisma = prisma) =>
  client.asignacionGuardia.findMany({
    where: { activa: true },
    select: {
      bicicleteroId: true,
      guardia: { select: { id: true, nombre: true } }
    }
  });

export const contarCompromisosActivos = async (
  bicicleteroId: string,
  client: ClientePrisma = prisma
) => {
  const asignaciones = await client.asignacionGuardia.count({
    where: { bicicleteroId, activa: true }
  });
  const solicitudes = await client.solicitudGuardia.count({
    where: { bicicleteroId, estado: { in: ['PENDIENTE', 'NOTIFICADA', 'EN_CAMINO'] } }
  });
  return { asignaciones, solicitudes };
};
