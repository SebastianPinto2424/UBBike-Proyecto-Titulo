import { Prisma } from '../../generated/prisma/client';
import { prisma, type ClientePrisma } from '../../configuracion/prisma';
import { RolUsuario } from './rol-usuario';

type FiltrosUsuarios = {
  q?: string;
  rol?: RolUsuario;
  cuentaActiva?: boolean;
  correoVerificado?: boolean;
};

export const buscarUsuarios = (filtros: FiltrosUsuarios, client: ClientePrisma = prisma) => {
  const q = filtros.q?.trim();

  return client.usuario.findMany({
    where: {
      eliminadoEn: null,
      ...(filtros.rol ? { rol: filtros.rol } : {}),
      ...(filtros.cuentaActiva !== undefined ? { cuentaActiva: filtros.cuentaActiva } : {}),
      ...(filtros.correoVerificado !== undefined
        ? { correoVerificado: filtros.correoVerificado }
        : {}),
      ...(q
        ? {
            OR: [
              { nombre: { contains: q, mode: 'insensitive' } },
              { correo: { contains: q, mode: 'insensitive' } },
              { rut: { contains: q, mode: 'insensitive' } }
            ]
          }
        : {})
    },
    orderBy: {
      creadoEn: 'desc'
    }
  });
};

export const buscarPorId = (id: string, client: ClientePrisma = prisma) =>
  client.usuario.findUnique({ where: { id } });

export const buscarPorCorreo = (correo: string, client: ClientePrisma = prisma) =>
  client.usuario.findUnique({ where: { correo } });

export const buscarPorRut = (rut: string, client: ClientePrisma = prisma) =>
  client.usuario.findUnique({ where: { rut } });

export const crear = (data: Prisma.UsuarioUncheckedCreateInput, client: ClientePrisma = prisma) =>
  client.usuario.create({ data });

export const actualizar = (
  id: string,
  data: Prisma.UsuarioUpdateInput,
  client: ClientePrisma = prisma
) => client.usuario.update({ where: { id }, data });

export const contarAdministradoresActivos = (
  excluirUsuarioId?: string,
  client: ClientePrisma = prisma
) =>
  client.usuario.count({
    where: {
      rol: RolUsuario.ADMINISTRADOR,
      cuentaActiva: true,
      correoVerificado: true,
      eliminadoEn: null,
      ...(excluirUsuarioId ? { id: { not: excluirUsuarioId } } : {})
    }
  });

export const contarAdministradoresSinCorreos = (
  correos: string[],
  client: ClientePrisma = prisma
) =>
  client.usuario.count({
    where: {
      rol: RolUsuario.ADMINISTRADOR,
      cuentaActiva: true,
      correoVerificado: true,
      eliminadoEn: null,
      correo: { notIn: correos }
    }
  });

export const desactivarCuentasPorCorreo = async (correos: string[]) => {
  const [resultado] = await prisma.$transaction([
    prisma.usuario.updateMany({
      where: { correo: { in: correos }, eliminadoEn: null },
      data: { cuentaActiva: false, eliminadoEn: new Date(), versionSesion: { increment: 1 } }
    }),
    prisma.dispositivoToken.deleteMany({
      where: { usuario: { correo: { in: correos } } }
    })
  ]);
  return resultado.count;
};
