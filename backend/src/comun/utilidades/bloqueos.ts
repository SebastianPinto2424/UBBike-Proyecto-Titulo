import { Prisma } from '../../generated/prisma/client';
import type { ClientePrisma } from '../../configuracion/prisma';

export const bloquearFila = async (
  db: ClientePrisma,
  tabla: 'bicicleteros' | 'incidencias' | 'solicitudes_guardia' | 'usuarios' | 'bicicletas',
  id: string
) => {
  await db.$queryRaw(
    Prisma.sql`SELECT id::text FROM ${Prisma.raw(tabla)} WHERE id = ${id}::uuid FOR UPDATE`
  );
};

export const bloquearClave = async (db: ClientePrisma, clave: string) => {
  await db.$queryRaw`SELECT pg_advisory_xact_lock(hashtextextended(${clave}, 0))::text`;
};
