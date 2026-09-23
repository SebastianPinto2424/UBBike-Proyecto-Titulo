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
