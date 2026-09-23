import { Prisma } from '../../generated/prisma/client';
import { prisma } from '../../configuracion/prisma';
import { RolUsuario } from '../usuarios/rol-usuario';

export const includeMovimientoCompleto = {
  usuario: true,
  bicicleta: true,
  bicicletero: true,
  validadoPorGuardia: true
} satisfies Prisma.MovimientoInclude;

export type MovimientoCompleto = Prisma.MovimientoGetPayload<{
  include: typeof includeMovimientoCompleto;
}>;

export const buscarMovimientos = (where: Prisma.MovimientoWhereInput, take: number, skip: number) =>
  prisma.movimiento.findMany({
    where,
    include: includeMovimientoCompleto,
    orderBy: { creadoEn: 'desc' },
    take,
    skip
  });

export const includeMovimientoExportacion = {
  usuario: {
    select: {
      id: true,
      nombre: true,
      correo: true,
      rut: true,
      rol: true,
      correoVerificado: true,
      cuentaActiva: true,
      creadoEn: true
    }
  },
  bicicleta: {
    select: {
      id: true,
      descripcion: true,
      marca: true,
      modelo: true,
      color: true,
      aro: true,
      numeroSerie: true,
      activa: true,
      dentroBicicletero: true,
      creadoEn: true
    }
  },
  bicicletero: { select: { id: true, nombre: true, ubicacion: true } },
  validadoPorGuardia: { select: { id: true, nombre: true, correo: true, rut: true } }
} satisfies Prisma.MovimientoInclude;

export type MovimientoExportacion = Prisma.MovimientoGetPayload<{
  include: typeof includeMovimientoExportacion;
}>;

export const buscarMovimientosExportacion = (where: Prisma.MovimientoWhereInput, take: number) =>
  prisma.movimiento.findMany({
    where,
    include: includeMovimientoExportacion,
    orderBy: { creadoEn: 'desc' },
    take
  });

export const contarMovimientos = (where: Prisma.MovimientoWhereInput) =>
  prisma.movimiento.count({ where });

export const agruparPorGuardia = (where: Prisma.MovimientoWhereInput) =>
  prisma.movimiento.groupBy({
    by: ['validadoPorGuardiaId'],
    where,
    _count: { _all: true },
    orderBy: { _count: { validadoPorGuardiaId: 'desc' } }
  });

export const agruparPorBicicletero = (where: Prisma.MovimientoWhereInput) =>
  prisma.movimiento.groupBy({
    by: ['bicicleteroId'],
    where,
    _count: { _all: true },
    orderBy: { _count: { bicicleteroId: 'desc' } }
  });

export const buscarNombresUsuarios = (ids: string[]) =>
  prisma.usuario.findMany({
    where: { id: { in: ids } },
    select: { id: true, nombre: true }
  });

export const buscarNombresBicicleteros = (ids: string[]) =>
  prisma.bicicletero.findMany({
    where: { id: { in: ids } },
    select: { id: true, nombre: true }
  });

export const listarGuardiasActivos = () =>
  prisma.usuario.findMany({
    where: { rol: RolUsuario.GUARDIA, cuentaActiva: true },
    orderBy: { nombre: 'asc' }
  });
export const contarPendientesOperativos = async () => {
  const [
    incidenciasAbiertas,
    solicitudesAbiertas,
    usuariosActivos,
    usuariosInactivos,
    usuariosSinVerificar
  ] = await Promise.all([
    prisma.incidencia.count({ where: { estado: { in: ['PENDIENTE', 'EN_REVISION'] } } }),
    prisma.solicitudGuardia.count({
      where: { estado: { in: ['PENDIENTE', 'NOTIFICADA', 'EN_CAMINO'] } }
    }),
    prisma.usuario.count({ where: { eliminadoEn: null, cuentaActiva: true } }),
    prisma.usuario.count({ where: { eliminadoEn: null, cuentaActiva: false } }),
    prisma.usuario.count({ where: { eliminadoEn: null, correoVerificado: false } })
  ]);
  return {
    incidenciasAbiertas,
    solicitudesAbiertas,
    usuariosActivos,
    usuariosInactivos,
    usuariosSinVerificar
  };
};
