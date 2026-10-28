import { Prisma } from '../../generated/prisma/client';
import { prisma, type ClientePrisma } from '../../configuracion/prisma';

const includeBicicleteroActual = {
  bicicleteroActual: {
    select: { id: true, nombre: true }
  }
} satisfies Prisma.BicicletaInclude;

export const ejecutarEnTransaccion = <T>(callback: (client: ClientePrisma) => Promise<T>) =>
  prisma.$transaction(callback);

export const buscarDeUsuario = (
  usuarioId: string,
  bicicletaId: string,
  client: ClientePrisma = prisma
) =>
  client.bicicleta.findFirst({
    where: { id: bicicletaId, usuarioId, eliminadoEn: null },
    include: includeBicicleteroActual
  });

export const listarDeUsuario = (usuarioId: string, client: ClientePrisma = prisma) =>
  client.bicicleta.findMany({
    where: { usuarioId, eliminadoEn: null },
    include: includeBicicleteroActual,
    orderBy: [{ activa: 'desc' }, { actualizadoEn: 'desc' }]
  });

export const buscarActivaDeUsuario = (usuarioId: string, client: ClientePrisma = prisma) =>
  client.bicicleta.findFirst({
    where: { usuarioId, activa: true, eliminadoEn: null },
    include: includeBicicleteroActual
  });

export const buscarSiguienteActivable = (usuarioId: string, client: ClientePrisma = prisma) =>
  client.bicicleta.findFirst({
    where: { usuarioId, eliminadoEn: null },
    orderBy: { actualizadoEn: 'desc' }
  });

export const contarDeUsuario = (usuarioId: string, client: ClientePrisma = prisma) =>
  client.bicicleta.count({ where: { usuarioId, eliminadoEn: null } });

export const crear = (data: Prisma.BicicletaUncheckedCreateInput, client: ClientePrisma = prisma) =>
  client.bicicleta.create({ data });

export const desactivarTodasDeUsuario = (usuarioId: string, client: ClientePrisma = prisma) =>
  client.bicicleta.updateMany({
    where: { usuarioId, eliminadoEn: null },
    data: { activa: false }
  });

export const actualizar = (
  id: string,
  data: Prisma.BicicletaUpdateInput,
  client: ClientePrisma = prisma
) => client.bicicleta.update({ where: { id }, data });

export const actualizarConBicicletero = (
  id: string,
  data: Prisma.BicicletaUpdateInput,
  client: ClientePrisma = prisma
) =>
  client.bicicleta.update({
    where: { id },
    data,
    include: includeBicicleteroActual
  });

export const eliminarSiEstaFuera = (
  id: string,
  usuarioId: string,
  client: ClientePrisma = prisma
) =>
  client.bicicleta.updateMany({
    where: { id, usuarioId, eliminadoEn: null, dentroBicicletero: false },
    data: { eliminadoEn: new Date(), activa: false }
  });
