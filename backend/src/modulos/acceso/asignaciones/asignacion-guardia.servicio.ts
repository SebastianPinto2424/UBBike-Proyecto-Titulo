import { ErrorHttp } from '../../../comun/errors/error-http';
import { bloquearClave, bloquearFila } from '../../../comun/utils/bloqueos';
import type { AsignacionGuardia, Bicicletero } from '../../../generated/prisma/client';
import { registrarAuditoria } from '../../auditoria/auditoria.servicio';
import {
  construirStatsBicicletero,
  contarOcupadosBicicletero
} from '../../bicicleteros/bicicletero.ocupacion';
import {
  crearNotificacion,
  ejecutarEfectosDiferidos,
  type EfectosDiferidos
} from '../../notificaciones/notificacion.servicio';
import { TipoNotificacion } from '../../notificaciones/tipo-notificacion';
import * as asignacionGuardiaRepositorio from './asignacion-guardia.repositorio';

const mapearBicicletero = async (bicicletero: Bicicletero) => {
  const ocupados = await contarOcupadosBicicletero(bicicletero.id);
  return construirStatsBicicletero(bicicletero, ocupados);
};

const mapearAsignacion = async (asignacion: AsignacionGuardia & { bicicletero: Bicicletero }) => ({
  id: asignacion.id,
  iniciaEn: asignacion.iniciaEn,
  bicicletero: await mapearBicicletero(asignacion.bicicletero)
});

export const obtenerAsignacionActivaGuardia = async (guardiaId: string) => {
  const asignacion = await asignacionGuardiaRepositorio.buscarActivaConBicicletero(guardiaId);

  return asignacion ? mapearAsignacion(asignacion) : null;
};

export const seleccionarBicicleteroGuardia = async (guardiaId: string, bicicleteroId: string) => {
  const efectos: EfectosDiferidos = [];
  const resultado = await asignacionGuardiaRepositorio.ejecutarEnTransaccion(async (db) => {
    await bloquearClave(db, `asignacion:${guardiaId}`);
    await bloquearFila(db, 'bicicleteros', bicicleteroId);
    const bicicletero = await asignacionGuardiaRepositorio.buscarBicicleteroActivo(
      bicicleteroId,
      db
    );

    if (!bicicletero) {
      throw new ErrorHttp(404, 'Bicicletero no encontrado o inactivo');
    }

    const ahora = new Date();

    await asignacionGuardiaRepositorio.cerrarActivasDeGuardia(guardiaId, ahora, db);

    const asignacion = await asignacionGuardiaRepositorio.crear(
      {
        guardiaId,
        bicicleteroId: bicicletero.id,
        iniciaEn: ahora,
        terminaEn: null,
        activa: true
      },
      db
    );

    await registrarAuditoria(
      {
        actorUsuarioId: guardiaId,
        accion: 'GUARDIA_BICICLETERO_SELECCIONADO',
        entidad: 'asignaciones_guardias',
        entidadId: asignacion.id,
        datos: {
          bicicleteroId: bicicletero.id
        }
      },
      db
    );

    await crearNotificacion(
      {
        usuarioId: guardiaId,
        titulo: 'Bicicletero asignado',
        mensaje: `Ahora gestionas ${bicicletero.nombre} durante tu turno.`,
        tipo: TipoNotificacion.SISTEMA,
        datos: {
          bicicleteroId: bicicletero.id,
          asignacionId: asignacion.id
        }
      },
      db,
      efectos
    );

    return {
      ...asignacion,
      bicicletero
    };
  });

  ejecutarEfectosDiferidos(efectos);
  return mapearAsignacion(resultado);
};

export const liberarBicicleteroGuardia = async (guardiaId: string) => {
  await asignacionGuardiaRepositorio.ejecutarEnTransaccion(async (db) => {
    await bloquearClave(db, `asignacion:${guardiaId}`);
    await asignacionGuardiaRepositorio.cerrarActivasDeGuardia(guardiaId, new Date(), db);

    await registrarAuditoria(
      {
        actorUsuarioId: guardiaId,
        accion: 'GUARDIA_BICICLETERO_LIBERADO',
        entidad: 'asignaciones_guardias',
        entidadId: guardiaId,
        datos: {}
      },
      db
    );
  });

  return { message: 'Ya no gestionas un bicicletero' };
};
