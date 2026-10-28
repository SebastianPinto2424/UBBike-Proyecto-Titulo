import type { Prisma } from '../../generated/prisma/client';
import { prisma, type ClientePrisma } from '../../configuracion/prisma';

export const encolarEntrega = (
  tipo: 'CORREO' | 'PUSH',
  datos: unknown,
  db: ClientePrisma = prisma
) =>
  db.entregaPendiente.create({
    data: { tipo, datos: JSON.parse(JSON.stringify(datos)) as Prisma.InputJsonValue }
  });

export const buscarPendientes = (ahora: Date, limite = 20) =>
  prisma.entregaPendiente.findMany({
    where: { entregadaEn: null, agotada: false, disponibleEn: { lte: ahora } },
    orderBy: { disponibleEn: 'asc' },
    take: limite
  });

export const reservar = (
  entrega: { id: string; intentos: number },
  ahora: Date,
  reintentarDesde: Date
) =>
  prisma.entregaPendiente.updateMany({
    where: {
      id: entrega.id,
      intentos: entrega.intentos,
      entregadaEn: null,
      agotada: false,
      disponibleEn: { lte: ahora }
    },
    data: { intentos: entrega.intentos + 1, disponibleEn: reintentarDesde }
  });

export const marcarEntregada = (id: string, intento: number) =>
  prisma.entregaPendiente.updateMany({
    where: { id, intentos: intento },
    data: { entregadaEn: new Date(), datos: {} }
  });

export const registrarFallo = (
  id: string,
  intento: number,
  agotada: boolean,
  reintentarDesde: Date
) =>
  prisma.entregaPendiente.updateMany({
    where: { id, intentos: intento },
    data: {
      agotada,
      disponibleEn: reintentarDesde,
      ...(agotada ? { datos: {} } : {})
    }
  });

export const buscarDestinatario = (usuarioId: string) =>
  prisma.usuario.findUnique({ where: { id: usuarioId } });
