import { Prisma } from '../../generated/prisma/client';
import { prisma, type ClientePrisma } from '../../configuracion/prisma';

const includeCodigoCompleto = {
  usuario: true,
  bicicleta: {
    include: {
      bicicleteroActual: true
    }
  },
  bicicletero: true
} satisfies Prisma.CodigoQrTemporalInclude;

export const ejecutarEnTransaccion = <T>(callback: (client: ClientePrisma) => Promise<T>) =>
  prisma.$transaction(callback);

export const buscarBicicletaParaQr = (
  usuarioId: string,
  bicicletaId: string | undefined,
  client: ClientePrisma = prisma
) =>
  client.bicicleta.findFirst({
    where: bicicletaId
      ? { id: bicicletaId, usuarioId, eliminadoEn: null }
      : { activa: true, usuarioId, eliminadoEn: null },
    include: {
      usuario: true,
      bicicleteroActual: true
    }
  });

export const buscarBicicletero = (id: string, client: ClientePrisma = prisma) =>
  client.bicicletero.findUnique({ where: { id } });

export const invalidarQrActivos = (usuarioId: string, client: ClientePrisma = prisma) =>
  client.codigoQrTemporal.updateMany({
    where: { usuarioId, usado: false },
    data: { usado: true }
  });

export const crearQr = (
  data: Prisma.CodigoQrTemporalUncheckedCreateInput,
  client: ClientePrisma = prisma
) => client.codigoQrTemporal.create({ data });

export const buscarAsignacionActiva = (
  guardiaId: string,
  bicicleteroId: string,
  client: ClientePrisma = prisma
) =>
  client.asignacionGuardia.findFirst({
    where: { guardiaId, bicicleteroId, activa: true }
  });

export const marcarEscaneadoPorGuardia = (
  qrId: string,
  validadorUsuarioId: string,
  client: ClientePrisma = prisma
) =>
  client.codigoQrTemporal.updateMany({
    where: {
      id: qrId,
      usado: false,
      OR: [{ escaneadoPorGuardiaId: null }, { escaneadoPorGuardiaId: validadorUsuarioId }]
    },
    data: {
      escaneadoPorGuardiaId: validadorUsuarioId,
      escaneadoEn: new Date()
    }
  });

export const liberarEscaneoDeGuardia = (
  qrId: string,
  validadorUsuarioId: string,
  client: ClientePrisma = prisma
) =>
  client.codigoQrTemporal.updateMany({
    where: { id: qrId, usado: false, escaneadoPorGuardiaId: validadorUsuarioId },
    data: { escaneadoPorGuardiaId: null, escaneadoEn: null }
  });

export const buscarCodigoDeUsuario = (
  qrId: string,
  usuarioId: string,
  client: ClientePrisma = prisma
) => client.codigoQrTemporal.findFirst({ where: { id: qrId, usuarioId } });

export const buscarMovimientoDeQr = (
  codigo: Pick<Prisma.CodigoQrTemporalGetPayload<object>, 'usuarioId' | 'bicicletaId' | 'tipo'> & {
    escaneadoEn: Date;
  },
  client: ClientePrisma = prisma
) =>
  client.movimiento.findFirst({
    where: {
      usuarioId: codigo.usuarioId,
      bicicletaId: codigo.bicicletaId,
      tipo: codigo.tipo,
      origen: 'QR',
      creadoEn: { gte: codigo.escaneadoEn }
    },
    orderBy: { creadoEn: 'desc' }
  });

export const buscarCodigoCompletoPorToken = (token: string, client: ClientePrisma = prisma) =>
  client.codigoQrTemporal.findFirst({
    where: { token },
    include: includeCodigoCompleto
  });
