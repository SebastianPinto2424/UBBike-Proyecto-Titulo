import { Prisma } from '../../../generated/prisma/client';
import { prisma, type ClientePrisma } from '../../../configuracion/prisma';

export const ejecutarEnTransaccion = <T>(callback: (client: ClientePrisma) => Promise<T>) =>
  prisma.$transaction(callback);

export const buscarActivaConBicicletero = (guardiaId: string, client: ClientePrisma = prisma) =>
  client.asignacionGuardia.findFirst({
    where: {
      guardiaId,
      activa: true
    },
    include: {
      bicicletero: true
    },
    orderBy: {
      iniciaEn: 'desc'
    }
  });

export const buscarActivaDeBicicletero = (bicicleteroId: string, client: ClientePrisma = prisma) =>
  client.asignacionGuardia.findFirst({
    where: {
      bicicleteroId,
      activa: true
    },
    include: {
      guardia: {
        select: {
          nombre: true
        }
      },
      bicicletero: {
        select: {
          nombre: true
        }
      }
    }
  });

export const cerrarActivaPorId = (id: string, terminaEn: Date, client: ClientePrisma = prisma) =>
  client.asignacionGuardia.updateMany({
    where: {
      id,
      activa: true
    },
    data: {
      activa: false,
      terminaEn
    }
  });

export const buscarBicicleteroActivo = (id: string, client: ClientePrisma = prisma) =>
  client.bicicletero.findFirst({
    where: {
      id,
      activo: true
    }
  });

export const cerrarActivasDeGuardia = (
  guardiaId: string,
  terminaEn: Date,
  client: ClientePrisma = prisma
) =>
  client.asignacionGuardia.updateMany({
    where: {
      guardiaId,
      activa: true
    },
    data: {
      activa: false,
      terminaEn
    }
  });

export const crear = (
  data: Prisma.AsignacionGuardiaUncheckedCreateInput,
  client: ClientePrisma = prisma
) => client.asignacionGuardia.create({ data });

const filtroGuardiaHabilitado = {
  rol: 'GUARDIA',
  cuentaActiva: true,
  debeCambiarContrasena: false,
  eliminadoEn: null
} satisfies Prisma.UsuarioWhereInput;

export const buscarGuardiaHabilitado = (id: string, client: ClientePrisma = prisma) =>
  client.usuario.findFirst({
    where: { id, ...filtroGuardiaHabilitado },
    select: { id: true, nombre: true }
  });

export const listarGuardiasHabilitados = (client: ClientePrisma = prisma) =>
  client.usuario.findMany({
    where: filtroGuardiaHabilitado,
    select: {
      id: true,
      nombre: true,
      asignacionesGuardia: {
        where: { activa: true },
        select: { bicicletero: { select: { id: true, nombre: true } } }
      }
    },
    orderBy: { nombre: 'asc' }
  });
