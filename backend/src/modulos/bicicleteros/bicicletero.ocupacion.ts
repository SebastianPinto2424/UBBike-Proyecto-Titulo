import type { ClientePrisma } from '../../configuracion/prisma';
import type { Bicicletero } from '../../generated/prisma/client';
import * as bicicleteroRepositorio from './bicicletero.repositorio';

export type EstadisticasBicicletero = {
  id: string;
  nombre: string;
  ubicacion: string;
  latitud: number | null;
  longitud: number | null;
  capacidad: number;
  ocupados: number;
  cuposDisponibles: number;
  porcentajeUso: number;
};

export const contarOcupadosPorBicicletero = async (
  db?: ClientePrisma
): Promise<Record<string, number>> => {
  const grupos = await bicicleteroRepositorio.contarOcupadosAgrupados(db);

  return Object.fromEntries(
    grupos
      .filter((grupo) => grupo.bicicleteroActualId)
      .map((grupo) => [grupo.bicicleteroActualId!, grupo._count._all])
  );
};

export const contarOcupadosBicicletero = async (
  bicicleteroId: string,
  db?: ClientePrisma
): Promise<number> => bicicleteroRepositorio.contarOcupados(bicicleteroId, db);

export const construirEstadisticasBicicletero = (
  bicicletero: Bicicletero,
  ocupados: number
): EstadisticasBicicletero => {
  const capacidad = Math.max(bicicletero.capacidad, 1);

  return {
    id: bicicletero.id,
    nombre: bicicletero.nombre,
    ubicacion: bicicletero.ubicacion,
    latitud: bicicletero.latitud,
    longitud: bicicletero.longitud,
    capacidad,
    ocupados,
    cuposDisponibles: Math.max(capacidad - ocupados, 0),
    porcentajeUso: Math.min(Math.round((ocupados / capacidad) * 100), 100)
  };
};
