import { ErrorHttp } from '../../comun/errors/error-http';
import { prisma, type ClientePrisma } from '../../configuracion/prisma';
import { bloquearFila } from '../../comun/utils/bloqueos';
import {
  construirStatsBicicletero,
  contarOcupadosBicicletero,
  contarOcupadosPorBicicletero
} from './bicicletero.ocupacion';
import * as bicicleteroRepositorio from './bicicletero.repositorio';

export const listarBicicleteros = async () => {
  const [bicicleteros, ocupadosPorId] = await Promise.all([
    bicicleteroRepositorio.listarActivos(),
    contarOcupadosPorBicicletero()
  ]);

  return bicicleteros.map((bicicletero) =>
    construirStatsBicicletero(bicicletero, ocupadosPorId[bicicletero.id] ?? 0)
  );
};

type DatosCrearBicicletero = {
  nombre: string;
  ubicacion: string;
  capacidad: number;
  latitud?: number | null;
  longitud?: number | null;
};

export const crearBicicletero = async (datos: DatosCrearBicicletero) => {
  const existente = await bicicleteroRepositorio.buscarPorNombre(datos.nombre);

  if (existente?.activo) {
    throw new ErrorHttp(409, 'Ya existe un bicicletero con ese nombre');
  }

  if (existente) {
    const reactivado = await bicicleteroRepositorio.actualizar(existente.id, {
      ubicacion: datos.ubicacion,
      capacidad: datos.capacidad,
      latitud: datos.latitud ?? null,
      longitud: datos.longitud ?? null,
      activo: true
    });

    const ocupados = await bicicleteroRepositorio.contarOcupados(reactivado.id);
    return construirStatsBicicletero(reactivado, ocupados);
  }

  const bicicletero = await bicicleteroRepositorio.crear({
    nombre: datos.nombre,
    ubicacion: datos.ubicacion,
    capacidad: datos.capacidad,
    latitud: datos.latitud ?? null,
    longitud: datos.longitud ?? null
  });

  return construirStatsBicicletero(bicicletero, 0);
};

const buscarBicicleteroExistente = async (bicicleteroId: string, db: ClientePrisma) => {
  await bloquearFila(db, 'bicicleteros', bicicleteroId);
  const bicicletero = await bicicleteroRepositorio.buscarPorId(bicicleteroId, db);

  if (!bicicletero) {
    throw new ErrorHttp(404, 'Bicicletero no encontrado');
  }

  return bicicletero;
};

type DatosActualizarBicicletero = {
  nombre?: string;
  ubicacion?: string;
  capacidad?: number;
  latitud?: number | null;
  longitud?: number | null;
};

export const actualizarBicicletero = async (
  bicicleteroId: string,
  datos: DatosActualizarBicicletero
) =>
  prisma.$transaction(async (db) => {
    await buscarBicicleteroExistente(bicicleteroId, db);
    const ocupados = await contarOcupadosBicicletero(bicicleteroId, db);
    if (datos.capacidad !== undefined && datos.capacidad < ocupados) {
      throw new ErrorHttp(409, 'La capacidad no puede ser menor que la ocupación actual');
    }

    const bicicletero = await bicicleteroRepositorio.actualizar(
      bicicleteroId,
      {
        nombre: datos.nombre,
        ubicacion: datos.ubicacion,
        capacidad: datos.capacidad,
        ...(datos.latitud !== undefined ? { latitud: datos.latitud } : {}),
        ...(datos.longitud !== undefined ? { longitud: datos.longitud } : {})
      },
      db
    );

    return construirStatsBicicletero(bicicletero, ocupados);
  });

export const eliminarBicicletero = async (bicicleteroId: string) =>
  prisma.$transaction(async (db) => {
    await buscarBicicleteroExistente(bicicleteroId, db);

    const ocupados = await contarOcupadosBicicletero(bicicleteroId, db);

    if (ocupados > 0) {
      throw new ErrorHttp(
        409,
        ocupados === 1
          ? 'No puedes eliminar un bicicletero con 1 bicicleta dentro. Registra primero su retiro.'
          : `No puedes eliminar un bicicletero con ${ocupados} bicicletas dentro. Registra primero sus retiros.`
      );
    }

    const [asignaciones, solicitudes] = await Promise.all([
      db.asignacionGuardia.count({ where: { bicicleteroId, activa: true } }),
      db.solicitudGuardia.count({
        where: { bicicleteroId, estado: { in: ['PENDIENTE', 'NOTIFICADA', 'EN_CAMINO'] } }
      })
    ]);
    if (asignaciones || solicitudes)
      throw new ErrorHttp(
        409,
        'Cierra las solicitudes y libera los guardias antes de eliminar el bicicletero'
      );
    await bicicleteroRepositorio.actualizar(bicicleteroId, { activo: false }, db);

    return { message: 'Bicicletero eliminado correctamente' };
  });
