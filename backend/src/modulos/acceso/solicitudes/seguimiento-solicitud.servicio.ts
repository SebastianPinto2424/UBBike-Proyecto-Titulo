import { ErrorHttp } from '../../../comun/errores/error-http';
import { registrarAuditoria } from '../../auditoria/auditoria.servicio';
import {
  crearNotificacion,
  ejecutarEfectosDiferidos,
  notificarUsuariosPorRol,
  type EfectosDiferidos
} from '../../notificaciones/notificacion.servicio';
import { TipoNotificacion } from '../../notificaciones/tipo-notificacion';
import { RolUsuario } from '../../usuarios/rol-usuario';
import {
  EventosTiempoReal,
  emitirTiempoReal,
  salaRol,
  salaUsuario
} from '../../../tiempo-real/tiempo-real';
import { EstadoSolicitudGuardia } from './estado-solicitud-guardia';
import * as solicitudGuardiaRepositorio from './solicitud-guardia.repositorio';
import {
  rolesCentral,
  rolesGestionSolicitudes,
  estadosCerrados,
  validarCambioDeEstado,
  validarRecordatorioCentral
} from './solicitud-guardia.reglas';
import {
  tituloSolicitudParaUsuario,
  mensajeSolicitudParaUsuario,
  mapearSolicitudGuardia
} from './solicitud-guardia.mapeador';

export const actualizarEstadoSolicitudGuardia = async (
  usuarioId: string,
  rol: string,
  solicitudId: string,
  estado: EstadoSolicitudGuardia,
  nota?: string | null
) => {
  if (!rolesGestionSolicitudes.includes(rol)) {
    throw new ErrorHttp(403, 'No tienes permisos para actualizar solicitudes');
  }

  validarCambioDeEstado(rol, estado);

  const efectos: EfectosDiferidos = [];
  const resultado = await solicitudGuardiaRepositorio.ejecutarEnTransaccion(async (db) => {
    const solicitud = await solicitudGuardiaRepositorio.buscarPorId(solicitudId, db);

    if (!solicitud) {
      throw new ErrorHttp(404, 'Solicitud no encontrada');
    }

    if (estadosCerrados.includes(solicitud.estado)) {
      throw new ErrorHttp(409, 'La solicitud ya está cerrada');
    }

    if (rol === RolUsuario.GUARDIA && solicitud.guardiaAsignado?.id !== usuarioId) {
      throw new ErrorHttp(403, 'La solicitud no está asignada a este guardia');
    }

    if (estado === EstadoSolicitudGuardia.NOTIFICADA) {
      validarRecordatorioCentral(solicitud, rol);
    }

    const notaLimpia = nota?.trim() || null;
    const cierreDeCentral =
      rolesCentral.includes(rol) && estado === EstadoSolicitudGuardia.CANCELADA;

    if (cierreDeCentral && !notaLimpia) {
      throw new ErrorHttp(400, 'Debes indicar un motivo para cerrar la solicitud');
    }

    const guardiaResponde =
      rol === RolUsuario.GUARDIA && estado === EstadoSolicitudGuardia.EN_CAMINO;
    const ahora = new Date();

    const solicitudActualizada = await solicitudGuardiaRepositorio.actualizar(
      solicitud.id,
      {
        estado,
        notificadaGuardiaEn:
          estado === EstadoSolicitudGuardia.NOTIFICADA ? ahora : solicitud.notificadaGuardiaEn,
        notificacionesGuardia:
          estado === EstadoSolicitudGuardia.NOTIFICADA
            ? {
                increment: 1
              }
            : undefined,
        respondidaPorGuardiaEn:
          guardiaResponde && !solicitud.respondidaPorGuardiaEn
            ? ahora
            : solicitud.respondidaPorGuardiaEn,
        enCaminoEn:
          estado === EstadoSolicitudGuardia.EN_CAMINO
            ? (solicitud.enCaminoEn ?? ahora)
            : solicitud.enCaminoEn,
        resueltaEn:
          estado === EstadoSolicitudGuardia.RESUELTA || estado === EstadoSolicitudGuardia.CANCELADA
            ? ahora
            : null,
        motivoCierre: cierreDeCentral ? notaLimpia : solicitud.motivoCierre,
        cerradaPorUsuario: estadosCerrados.includes(estado)
          ? { connect: { id: usuarioId } }
          : undefined
      },
      db
    );

    const estadosNotificablesUsuario: EstadoSolicitudGuardia[] = [
      EstadoSolicitudGuardia.EN_CAMINO,
      EstadoSolicitudGuardia.RESUELTA,
      EstadoSolicitudGuardia.CANCELADA
    ];

    if (estadosNotificablesUsuario.includes(estado)) {
      await crearNotificacion(
        {
          usuarioId: solicitud.solicitadaPorUsuario.id,
          titulo: tituloSolicitudParaUsuario(estado),
          mensaje: mensajeSolicitudParaUsuario(
            estado,
            solicitud.bicicletero.nombre,
            cierreDeCentral ? notaLimpia : null
          ),
          tipo: TipoNotificacion.SOLICITUD_GUARDIA,
          datos: { solicitudId: solicitud.id, estado }
        },
        db,
        efectos
      );
    }

    if (cierreDeCentral && solicitud.guardiaAsignado) {
      await crearNotificacion(
        {
          usuarioId: solicitud.guardiaAsignado.id,
          titulo: 'Solicitud cerrada',
          mensaje: `Central cerró la solicitud de ${solicitud.solicitadaPorUsuario.nombre} en ${solicitud.bicicletero.nombre}. Ya no es necesario ir.`,
          tipo: TipoNotificacion.SOLICITUD_GUARDIA,
          datos: { solicitudId: solicitud.id, bicicleteroId: solicitud.bicicletero.id, estado }
        },
        db,
        efectos
      );
    }

    if (estado === EstadoSolicitudGuardia.NOTIFICADA && rolesCentral.includes(rol)) {
      await crearNotificacion(
        {
          usuarioId: solicitud.guardiaAsignado!.id,
          titulo: 'Recordatorio de solicitud',
          mensaje: `Central pidió atender la solicitud de ${solicitud.solicitadaPorUsuario.nombre} en ${solicitud.bicicletero.nombre}.`,
          tipo: TipoNotificacion.SOLICITUD_GUARDIA,
          datos: {
            solicitudId: solicitud.id,
            bicicleteroId: solicitud.bicicletero.id,
            estado
          }
        },
        db,
        efectos
      );
    }

    if (guardiaResponde) {
      await notificarUsuariosPorRol(
        {
          roles: [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR],
          titulo: 'Guardia en camino',
          mensaje: `${solicitud.guardiaAsignado!.nombre} confirmó traslado hacia ${solicitud.bicicletero.nombre}.`,
          tipo: TipoNotificacion.SOLICITUD_GUARDIA,
          datos: {
            solicitudId: solicitud.id,
            bicicleteroId: solicitud.bicicletero.id,
            estado
          }
        },
        db,
        efectos
      );
    }

    await registrarAuditoria(
      {
        actorUsuarioId: usuarioId,
        accion: 'SOLICITUD_GUARDIA_ESTADO_ACTUALIZADO',
        entidad: 'solicitudes_guardia',
        entidadId: solicitud.id,
        datos: {
          estado,
          rolActor: rol,
          bicicleteroId: solicitud.bicicletero.id,
          guardiaAsignadoId: solicitud.guardiaAsignado?.id ?? null,
          cierreDeCentral,
          motivoCierre: cierreDeCentral ? notaLimpia : undefined
        }
      },
      db
    );

    return {
      solicitud: mapearSolicitudGuardia(solicitudActualizada),
      solicitanteId: solicitudActualizada.solicitadaPorUsuario.id
    };
  });

  ejecutarEfectosDiferidos(efectos);
  emitirTiempoReal(
    [
      salaUsuario(resultado.solicitanteId),
      salaRol(RolUsuario.GUARDIA),
      salaRol(RolUsuario.ADMIN_CENTRAL),
      salaRol(RolUsuario.ADMINISTRADOR)
    ],
    EventosTiempoReal.SOLICITUD
  );

  return resultado.solicitud;
};

export const cancelarSolicitudGuardia = async (
  usuarioId: string,
  solicitudId: string,
  motivo: string
) => {
  const motivoLimpio = motivo?.trim();

  if (!motivoLimpio) {
    throw new ErrorHttp(400, 'Debes indicar un motivo para cancelar la solicitud');
  }

  const efectos: EfectosDiferidos = [];
  const resultado = await solicitudGuardiaRepositorio.ejecutarEnTransaccion(async (db) => {
    const solicitud = await solicitudGuardiaRepositorio.buscarPorId(solicitudId, db);

    if (!solicitud) {
      throw new ErrorHttp(404, 'Solicitud no encontrada');
    }

    if (solicitud.solicitadaPorUsuario.id !== usuarioId) {
      throw new ErrorHttp(403, 'Solo quien hizo la solicitud puede cancelarla');
    }

    if (estadosCerrados.includes(solicitud.estado)) {
      throw new ErrorHttp(409, 'La solicitud ya está cerrada');
    }

    const solicitudActualizada = await solicitudGuardiaRepositorio.actualizar(
      solicitud.id,
      {
        estado: EstadoSolicitudGuardia.CANCELADA,
        resueltaEn: new Date(),
        motivoCierre: motivoLimpio,
        cerradaPorUsuario: { connect: { id: usuarioId } }
      },
      db
    );

    if (solicitud.guardiaAsignado) {
      await crearNotificacion(
        {
          usuarioId: solicitud.guardiaAsignado.id,
          titulo: 'Solicitud cancelada',
          mensaje: `${solicitud.solicitadaPorUsuario.nombre} canceló su solicitud en ${solicitud.bicicletero.nombre}. Ya no es necesario ir. Motivo: ${motivoLimpio}`,
          tipo: TipoNotificacion.SOLICITUD_GUARDIA,
          datos: {
            solicitudId: solicitud.id,
            bicicleteroId: solicitud.bicicletero.id,
            estado: EstadoSolicitudGuardia.CANCELADA
          }
        },
        db,
        efectos
      );
    }

    await registrarAuditoria(
      {
        actorUsuarioId: usuarioId,
        accion: 'SOLICITUD_GUARDIA_CANCELADA_POR_SOLICITANTE',
        entidad: 'solicitudes_guardia',
        entidadId: solicitud.id,
        datos: {
          estadoAnterior: solicitud.estado,
          bicicleteroId: solicitud.bicicletero.id,
          guardiaAsignadoId: solicitud.guardiaAsignado?.id ?? null,
          motivo: motivoLimpio
        }
      },
      db
    );

    return mapearSolicitudGuardia(solicitudActualizada);
  });

  ejecutarEfectosDiferidos(efectos);
  emitirTiempoReal(
    [
      salaUsuario(usuarioId),
      salaRol(RolUsuario.GUARDIA),
      salaRol(RolUsuario.ADMIN_CENTRAL),
      salaRol(RolUsuario.ADMINISTRADOR)
    ],
    EventosTiempoReal.SOLICITUD
  );

  return resultado;
};
