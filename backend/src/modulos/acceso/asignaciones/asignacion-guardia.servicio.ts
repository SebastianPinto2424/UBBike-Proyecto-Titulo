import { ErrorHttp } from '../../../comun/errores/error-http';
import { bloquearClave, bloquearFila } from '../../../comun/utilidades/bloqueos';
import type { AsignacionGuardia, Bicicletero } from '../../../generated/prisma/client';
import {
  EventosTiempoReal,
  emitirTiempoReal,
  salaRol,
  salaUsuario
} from '../../../tiempo-real/tiempo-real';
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
import { RolUsuario } from '../../usuarios/rol-usuario';
import {
  contarSolicitudes,
  devolverSolicitudesSinRespuesta,
  traspasarSolicitudesAlGuardia
} from '../solicitudes/traspaso-solicitud.servicio';
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

const avisarCambios = (solicitantes: string[]) => {
  const personal = [
    salaRol(RolUsuario.GUARDIA),
    salaRol(RolUsuario.ADMIN_CENTRAL),
    salaRol(RolUsuario.ADMINISTRADOR)
  ];
  emitirTiempoReal(personal, EventosTiempoReal.BICICLETEROS);

  if (solicitantes.length) {
    emitirTiempoReal(
      [...personal, ...[...new Set(solicitantes)].map((usuarioId) => salaUsuario(usuarioId))],
      EventosTiempoReal.SOLICITUD
    );
  }
};

export const obtenerAsignacionActivaGuardia = async (guardiaId: string) => {
  const asignacion = await asignacionGuardiaRepositorio.buscarActivaConBicicletero(guardiaId);

  return asignacion ? mapearAsignacion(asignacion) : null;
};

type Ocupacion = {
  guardiaId: string;
  bicicleteroId: string;
  actorUsuarioId: string;
};

const ocuparBicicletero = async ({ guardiaId, bicicleteroId, actorUsuarioId }: Ocupacion) => {
  const porCentral = actorUsuarioId !== guardiaId;
  const efectos: EfectosDiferidos = [];
  const resultado = await asignacionGuardiaRepositorio.ejecutarEnTransaccion(async (db) => {
    await bloquearClave(db, `asignacion:${guardiaId}`);
    await bloquearFila(db, 'bicicleteros', bicicleteroId);

    if (
      porCentral &&
      !(await asignacionGuardiaRepositorio.buscarGuardiaHabilitado(guardiaId, db))
    ) {
      throw new ErrorHttp(404, 'Guardia no encontrado o con la cuenta inactiva');
    }

    const bicicletero = await asignacionGuardiaRepositorio.buscarBicicleteroActivo(
      bicicleteroId,
      db
    );

    if (!bicicletero) {
      throw new ErrorHttp(404, 'Bicicletero no encontrado o inactivo');
    }

    const asignacionVigente = await asignacionGuardiaRepositorio.buscarActivaDeBicicletero(
      bicicletero.id,
      db
    );

    if (asignacionVigente && asignacionVigente.guardiaId !== guardiaId) {
      throw new ErrorHttp(
        409,
        porCentral
          ? `${asignacionVigente.guardia.nombre} ya gestiona ${bicicletero.nombre}. Libéralo antes de asignar a otro guardia.`
          : `${asignacionVigente.guardia.nombre} ya gestiona ${bicicletero.nombre}. Debe liberarlo antes de que puedas tomarlo.`
      );
    }

    const ahora = new Date();

    await asignacionGuardiaRepositorio.cerrarActivasDeGuardia(guardiaId, ahora, db);
    const devueltas = await devolverSolicitudesSinRespuesta(guardiaId, bicicletero.id, db, efectos);

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

    const traspasadas = await traspasarSolicitudesAlGuardia(guardiaId, bicicletero, db, efectos);

    await registrarAuditoria(
      {
        actorUsuarioId,
        accion: porCentral
          ? 'GUARDIA_BICICLETERO_ASIGNADO_POR_CENTRAL'
          : 'GUARDIA_BICICLETERO_SELECCIONADO',
        entidad: 'asignaciones_guardias',
        entidadId: asignacion.id,
        datos: {
          bicicleteroId: bicicletero.id,
          guardiaId
        }
      },
      db
    );

    const turno = porCentral
      ? `Central te asignó ${bicicletero.nombre}.`
      : `Ahora gestionas ${bicicletero.nombre} durante tu turno.`;
    await crearNotificacion(
      {
        usuarioId: guardiaId,
        titulo: traspasadas.length ? 'Solicitudes pendientes' : 'Bicicletero asignado',
        mensaje: traspasadas.length
          ? `${turno} Tienes ${contarSolicitudes(traspasadas.length)}.`
          : turno,
        tipo: traspasadas.length ? TipoNotificacion.SOLICITUD_GUARDIA : TipoNotificacion.SISTEMA,
        push: porCentral || undefined,
        datos: {
          bicicleteroId: bicicletero.id,
          asignacionId: asignacion.id
        }
      },
      db,
      efectos
    );

    return {
      asignacion: { ...asignacion, bicicletero },
      solicitantes: [...devueltas, ...traspasadas]
    };
  });

  ejecutarEfectosDiferidos(efectos);
  avisarCambios(resultado.solicitantes);
  return mapearAsignacion(resultado.asignacion);
};

export const seleccionarBicicleteroGuardia = (guardiaId: string, bicicleteroId: string) =>
  ocuparBicicletero({ guardiaId, bicicleteroId, actorUsuarioId: guardiaId });

export const asignarGuardiaABicicletero = (
  bicicleteroId: string,
  guardiaId: string,
  actorUsuarioId: string
) => ocuparBicicletero({ guardiaId, bicicleteroId, actorUsuarioId });

export const listarGuardiasHabilitados = async () => {
  const guardias = await asignacionGuardiaRepositorio.listarGuardiasHabilitados();

  return guardias.map((guardia) => ({
    id: guardia.id,
    nombre: guardia.nombre,
    bicicletero: guardia.asignacionesGuardia[0]?.bicicletero ?? null
  }));
};

export const liberarBicicleteroGuardia = async (
  guardiaId: string,
  actorUsuarioId: string | null = guardiaId
) => {
  const efectos: EfectosDiferidos = [];
  const solicitantes = await asignacionGuardiaRepositorio.ejecutarEnTransaccion(async (db) => {
    await bloquearClave(db, `asignacion:${guardiaId}`);
    await asignacionGuardiaRepositorio.cerrarActivasDeGuardia(guardiaId, new Date(), db);
    const devueltas = await devolverSolicitudesSinRespuesta(guardiaId, null, db, efectos);

    await registrarAuditoria(
      {
        actorUsuarioId,
        accion: 'GUARDIA_BICICLETERO_LIBERADO',
        entidad: 'asignaciones_guardias',
        entidadId: guardiaId,
        datos: {}
      },
      db
    );

    return devueltas;
  });

  ejecutarEfectosDiferidos(efectos);
  avisarCambios(solicitantes);
  return { message: 'Ya no gestionas un bicicletero' };
};

export const liberarGuardiaDeBicicletero = async (
  bicicleteroId: string,
  actorUsuarioId: string
) => {
  const efectos: EfectosDiferidos = [];
  const solicitantes = await asignacionGuardiaRepositorio.ejecutarEnTransaccion(async (db) => {
    const asignacion = await asignacionGuardiaRepositorio.buscarActivaDeBicicletero(
      bicicleteroId,
      db
    );

    if (!asignacion) {
      throw new ErrorHttp(409, 'Nadie gestiona este bicicletero');
    }

    await bloquearClave(db, `asignacion:${asignacion.guardiaId}`);
    const cerradas = await asignacionGuardiaRepositorio.cerrarActivaPorId(
      asignacion.id,
      new Date(),
      db
    );

    if (!cerradas.count) {
      throw new ErrorHttp(
        409,
        `${asignacion.guardia.nombre} ya dejó ${asignacion.bicicletero.nombre}`
      );
    }

    const devueltas = await devolverSolicitudesSinRespuesta(
      asignacion.guardiaId,
      null,
      db,
      efectos
    );

    await crearNotificacion(
      {
        usuarioId: asignacion.guardiaId,
        titulo: 'Bicicletero liberado',
        mensaje: `Central liberó ${asignacion.bicicletero.nombre}. Ya no lo gestionas.`,
        tipo: TipoNotificacion.SISTEMA,
        push: true,
        datos: { bicicleteroId }
      },
      db,
      efectos
    );

    await registrarAuditoria(
      {
        actorUsuarioId,
        accion: 'GUARDIA_BICICLETERO_LIBERADO',
        entidad: 'asignaciones_guardias',
        entidadId: asignacion.guardiaId,
        datos: { bicicleteroId, asignacionId: asignacion.id, porCentral: true }
      },
      db
    );

    return devueltas;
  });

  ejecutarEfectosDiferidos(efectos);
  avisarCambios(solicitantes);
  return { message: 'Bicicletero liberado' };
};
