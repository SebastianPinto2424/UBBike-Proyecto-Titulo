import type { ClientePrisma } from '../../../configuracion/prisma';
import { registrarAuditoria } from '../../auditoria/auditoria.servicio';
import {
  crearNotificacion,
  notificarUsuariosPorRol,
  type EfectosDiferidos
} from '../../notificaciones/notificacion.servicio';
import { TipoNotificacion } from '../../notificaciones/tipo-notificacion';
import { RolUsuario } from '../../usuarios/rol-usuario';
import * as solicitudGuardiaRepositorio from './solicitud-guardia.repositorio';
import { estadosSinRespuesta } from './solicitud-guardia.reglas';

type BicicleteroTraspaso = { id: string; nombre: string };

export const contarSolicitudes = (cantidad: number) =>
  cantidad === 1 ? '1 solicitud pendiente' : `${cantidad} solicitudes pendientes`;

export const traspasarSolicitudesAlGuardia = async (
  guardiaId: string,
  bicicletero: BicicleteroTraspaso,
  db: ClientePrisma,
  efectos: EfectosDiferidos
) => {
  const solicitudes = await solicitudGuardiaRepositorio.listarSinAtenderDeBicicletero(
    { bicicleteroId: bicicletero.id, guardiaId, estados: estadosSinRespuesta },
    db
  );

  if (!solicitudes.length) {
    return [];
  }

  await solicitudGuardiaRepositorio.asignarGuardia(
    solicitudes.map((solicitud) => solicitud.id),
    guardiaId,
    new Date(),
    db
  );

  for (const solicitud of solicitudes) {
    await crearNotificacion(
      {
        usuarioId: solicitud.solicitadaPorUsuarioId,
        titulo: 'Guardia notificado',
        mensaje: `Un guardia recibió tu solicitud en ${bicicletero.nombre}.`,
        tipo: TipoNotificacion.SOLICITUD_GUARDIA,
        datos: { solicitudId: solicitud.id, bicicleteroId: bicicletero.id }
      },
      db,
      efectos
    );
  }

  await registrarAuditoria(
    {
      actorUsuarioId: guardiaId,
      accion: 'SOLICITUDES_GUARDIA_TRASPASADAS',
      entidad: 'solicitudes_guardia',
      entidadId: bicicletero.id,
      datos: {
        guardiaId,
        bicicleteroId: bicicletero.id,
        solicitudes: solicitudes.map((solicitud) => solicitud.id)
      }
    },
    db
  );

  return solicitudes.map((solicitud) => solicitud.solicitadaPorUsuarioId);
};

export const devolverSolicitudesSinRespuesta = async (
  guardiaId: string,
  exceptoBicicleteroId: string | null,
  db: ClientePrisma,
  efectos: EfectosDiferidos
) => {
  const solicitudes = await solicitudGuardiaRepositorio.listarSinRespuestaDeGuardia(
    { guardiaId, estados: estadosSinRespuesta, exceptoBicicleteroId },
    db
  );

  if (!solicitudes.length) {
    return [];
  }

  await solicitudGuardiaRepositorio.dejarSinGuardia(
    solicitudes.map((solicitud) => solicitud.id),
    db
  );

  const porBicicletero = new Map<string, typeof solicitudes>();
  for (const solicitud of solicitudes) {
    porBicicletero.set(solicitud.bicicletero.id, [
      ...(porBicicletero.get(solicitud.bicicletero.id) ?? []),
      solicitud
    ]);
  }

  for (const grupo of porBicicletero.values()) {
    const { bicicletero, guardiaAsignado } = grupo[0];
    await notificarUsuariosPorRol(
      {
        roles: [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR],
        titulo: 'Solicitudes sin guardia',
        mensaje: `${guardiaAsignado?.nombre ?? 'El guardia'} dejó de gestionar ${bicicletero.nombre}. Hay ${contarSolicitudes(grupo.length)} sin guardia.`,
        tipo: TipoNotificacion.SOLICITUD_GUARDIA,
        datos: { bicicleteroId: bicicletero.id }
      },
      db,
      efectos
    );

    for (const solicitud of grupo) {
      await crearNotificacion(
        {
          usuarioId: solicitud.solicitadaPorUsuarioId,
          titulo: 'Solicitud pendiente',
          mensaje: `El guardia dejó ${bicicletero.nombre}. Tu solicitud sigue pendiente y avisamos a central.`,
          tipo: TipoNotificacion.SOLICITUD_GUARDIA,
          datos: { solicitudId: solicitud.id, bicicleteroId: bicicletero.id }
        },
        db,
        efectos
      );
    }
  }

  await registrarAuditoria(
    {
      actorUsuarioId: guardiaId,
      accion: 'SOLICITUDES_GUARDIA_DEVUELTAS',
      entidad: 'solicitudes_guardia',
      entidadId: guardiaId,
      datos: { guardiaId, solicitudes: solicitudes.map((solicitud) => solicitud.id) }
    },
    db
  );

  return solicitudes.map((solicitud) => solicitud.solicitadaPorUsuarioId);
};
