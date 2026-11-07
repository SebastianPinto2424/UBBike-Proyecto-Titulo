import { ErrorHttp } from '../../../comun/errores/error-http';
import { bloquearClave, bloquearFila } from '../../../comun/utilidades/bloqueos';
import { alcancePropio, type AlcanceConsulta } from '../../../comun/utilidades/esquemas-comunes';
import type { ClientePrisma } from '../../../configuracion/prisma';
import { Prisma } from '../../../generated/prisma/client';
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
import type { SolicitudCompleta } from './solicitud-guardia.repositorio';
import { TipoSolicitudGuardia } from './tipo-solicitud-guardia';
import {
  rolesCentral,
  estadosCerrados,
  calcularSegundosParaRecordatorio,
  impedirAtencionPropia
} from './solicitud-guardia.reglas';
import { mapearSolicitudGuardia } from './solicitud-guardia.mapeador';

type DatosCrearSolicitud = {
  usuarioId: string;
  bicicleteroId: string;
  tipo: TipoSolicitudGuardia;
  mensaje?: string | null;
};

type DatosNotificarGuardia = {
  usuarioId: string;
  rol: string;
  solicitudId: string;
  mensaje?: string | null;
};

type DatosListarSolicitudes = {
  usuarioId: string;
  rol: string;
  estado?: EstadoSolicitudGuardia | 'TODOS';
  q?: string;
  limite?: number;
  alcance?: AlcanceConsulta;
};

const notificarGuardiaAsignado = async (
  solicitud: SolicitudCompleta,
  db: ClientePrisma,
  recordatorio = false,
  efectos?: EfectosDiferidos
) => {
  if (!solicitud.guardiaAsignado) {
    return;
  }

  await crearNotificacion(
    {
      usuarioId: solicitud.guardiaAsignado.id,
      titulo: recordatorio ? 'Recordatorio de solicitud' : 'Solicitud de apoyo',
      mensaje: recordatorio
        ? `${solicitud.solicitadaPorUsuario.nombre} sigue esperando apoyo en ${solicitud.bicicletero.nombre}.`
        : `${solicitud.solicitadaPorUsuario.nombre} solicita apoyo en ${solicitud.bicicletero.nombre}.`,
      tipo: TipoNotificacion.SOLICITUD_GUARDIA,
      datos: {
        solicitudId: solicitud.id,
        bicicleteroId: solicitud.bicicletero.id,
        solicitanteId: solicitud.solicitadaPorUsuario.id
      }
    },
    db,
    efectos
  );
};

const reiterarSolicitudAbierta = async (
  solicitud: SolicitudCompleta,
  usuarioId: string,
  rol: string,
  mensaje: string | null | undefined,
  db: ClientePrisma,
  efectos?: EfectosDiferidos
) => {
  const esCentral = rolesCentral.includes(rol);
  const esSolicitante = solicitud.solicitadaPorUsuario.id === usuarioId;

  if (!esCentral && !esSolicitante) {
    throw new ErrorHttp(403, 'Solo el solicitante o central pueden notificar nuevamente');
  }

  if (estadosCerrados.includes(solicitud.estado)) {
    throw new ErrorHttp(409, 'La solicitud ya está cerrada');
  }

  if (solicitud.guardiaAsignado) {
    if (solicitud.respondidaPorGuardiaEn || solicitud.estado === EstadoSolicitudGuardia.EN_CAMINO) {
      throw new ErrorHttp(409, 'El guardia ya respondió esta solicitud');
    }

    const segundosRestantes = calcularSegundosParaRecordatorio(solicitud);

    if (segundosRestantes !== null && segundosRestantes > 0) {
      throw new ErrorHttp(409, `Podrás enviar un nuevo aviso en ${segundosRestantes} segundos`);
    }
  }

  const mensajeLimpio = mensaje?.trim();
  const ahora = new Date();

  if (!solicitud.guardiaAsignado) {
    const solicitudActualizada = await solicitudGuardiaRepositorio.actualizar(
      solicitud.id,
      {
        mensaje: mensajeLimpio || solicitud.mensaje
      },
      db
    );

    await notificarUsuariosPorRol(
      {
        roles: [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR],
        titulo: 'Atención pendiente',
        mensaje: `${solicitud.solicitadaPorUsuario.nombre} reiteró una solicitud en ${solicitud.bicicletero.nombre}. Aún no hay guardia asignado.`,
        tipo: TipoNotificacion.SOLICITUD_GUARDIA,
        datos: {
          solicitudId: solicitud.id,
          bicicleteroId: solicitud.bicicletero.id,
          solicitanteId: solicitud.solicitadaPorUsuario.id
        },
        excluirUsuarioId: usuarioId
      },
      db,
      efectos
    );

    await registrarAuditoria(
      {
        actorUsuarioId: usuarioId,
        accion: 'SOLICITUD_GUARDIA_REITERADA_SIN_GUARDIA',
        entidad: 'solicitudes_guardia',
        entidadId: solicitud.id,
        datos: {
          rolActor: rol,
          bicicleteroId: solicitud.bicicletero.id
        }
      },
      db
    );

    return solicitudActualizada;
  }

  const solicitudActualizada = await solicitudGuardiaRepositorio.actualizar(
    solicitud.id,
    {
      estado:
        solicitud.estado === EstadoSolicitudGuardia.PENDIENTE
          ? EstadoSolicitudGuardia.NOTIFICADA
          : solicitud.estado,
      mensaje: mensajeLimpio || solicitud.mensaje,
      notificadaGuardiaEn: ahora,
      ultimaNotificacionUsuarioEn: esSolicitante ? ahora : solicitud.ultimaNotificacionUsuarioEn,
      notificacionesGuardia: {
        increment: 1
      }
    },
    db
  );

  await notificarGuardiaAsignado(solicitudActualizada, db, true, efectos);

  await registrarAuditoria(
    {
      actorUsuarioId: usuarioId,
      accion: 'SOLICITUD_GUARDIA_RENOTIFICADA',
      entidad: 'solicitudes_guardia',
      entidadId: solicitud.id,
      datos: {
        rolActor: rol,
        bicicleteroId: solicitud.bicicletero.id,
        guardiaAsignadoId: solicitud.guardiaAsignado.id,
        notificacionesGuardia: solicitudActualizada.notificacionesGuardia
      }
    },
    db
  );

  return solicitudActualizada;
};

export const crearSolicitudGuardia = async (datos: DatosCrearSolicitud) => {
  const efectos: EfectosDiferidos = [];
  const resultado = await solicitudGuardiaRepositorio.ejecutarEnTransaccion(async (db) => {
    await bloquearClave(db, `solicitud:${datos.usuarioId}:${datos.bicicleteroId}:${datos.tipo}`);
    await bloquearFila(db, 'bicicleteros', datos.bicicleteroId);
    const bicicletero = await solicitudGuardiaRepositorio.buscarBicicletero(
      datos.bicicleteroId,
      db
    );

    if (!bicicletero) {
      throw new ErrorHttp(404, 'Bicicletero no encontrado');
    }

    if (!bicicletero.activo) throw new ErrorHttp(409, 'El bicicletero está inactivo');
    const encontrada = await solicitudGuardiaRepositorio.buscarSolicitudAbierta(
      {
        usuarioId: datos.usuarioId,
        bicicleteroId: bicicletero.id,
        tipo: datos.tipo,
        estadosCerrados
      },
      db
    );

    const solicitudAbierta = encontrada
      ? await solicitudGuardiaRepositorio.buscarPorId(encontrada.id, db)
      : null;
    if (solicitudAbierta && !estadosCerrados.includes(solicitudAbierta.estado)) {
      const solicitudReiterada = await reiterarSolicitudAbierta(
        solicitudAbierta,
        datos.usuarioId,
        solicitudAbierta.solicitadaPorUsuario.rol,
        datos.mensaje,
        db,
        efectos
      );

      return {
        solicitud: mapearSolicitudGuardia(solicitudReiterada),
        solicitanteId: solicitudReiterada.solicitadaPorUsuario.id
      };
    }

    const asignacion = await solicitudGuardiaRepositorio.buscarAsignacionActivaConGuardia(
      datos.bicicleteroId,
      db
    );
    impedirAtencionPropia(asignacion?.guardia.id, datos.usuarioId);

    const solicitudGuardada = await solicitudGuardiaRepositorio.crear(
      {
        solicitadaPorUsuarioId: datos.usuarioId,
        bicicleteroId: bicicletero.id,
        guardiaAsignadoId: asignacion?.guardia.id ?? null,
        tipo: datos.tipo,
        estado: asignacion?.guardia
          ? EstadoSolicitudGuardia.NOTIFICADA
          : EstadoSolicitudGuardia.PENDIENTE,
        mensaje: datos.mensaje || null,
        notificadaGuardiaEn: asignacion?.guardia ? new Date() : null,
        ultimaNotificacionUsuarioEn: asignacion?.guardia ? new Date() : null,
        notificacionesGuardia: asignacion?.guardia ? 1 : 0
      },
      db
    );

    await notificarGuardiaAsignado(solicitudGuardada, db, false, efectos);

    await notificarUsuariosPorRol(
      {
        roles: [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR],
        titulo: 'Nueva solicitud de atención',
        mensaje: `${solicitudGuardada.solicitadaPorUsuario.nombre} solicitó apoyo en ${bicicletero.nombre}.`,
        tipo: TipoNotificacion.SOLICITUD_GUARDIA,
        datos: { solicitudId: solicitudGuardada.id, bicicleteroId: bicicletero.id },
        excluirUsuarioId: datos.usuarioId
      },
      db,
      efectos
    );

    await registrarAuditoria(
      {
        actorUsuarioId: datos.usuarioId,
        accion: 'SOLICITUD_GUARDIA_CREADA',
        entidad: 'solicitudes_guardia',
        entidadId: solicitudGuardada.id,
        datos: {
          bicicleteroId: bicicletero.id,
          guardiaAsignadoId: asignacion?.guardia.id ?? null,
          tipo: datos.tipo
        }
      },
      db
    );

    const solicitudCompleta = await solicitudGuardiaRepositorio.buscarPorIdOError(
      solicitudGuardada.id,
      db
    );

    return {
      solicitud: mapearSolicitudGuardia(solicitudCompleta),
      solicitanteId: solicitudCompleta.solicitadaPorUsuario.id
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

export const listarSolicitudesGuardia = async (datos: DatosListarSolicitudes) => {
  const condiciones: Prisma.SolicitudGuardiaWhereInput[] = [];

  if (datos.alcance === alcancePropio) {
    condiciones.push({ solicitadaPorUsuarioId: datos.usuarioId });
  } else if (datos.rol === RolUsuario.GUARDIA) {
    condiciones.push({ guardiaAsignadoId: datos.usuarioId });
  } else if (!rolesCentral.includes(datos.rol)) {
    condiciones.push({ solicitadaPorUsuarioId: datos.usuarioId });
  }

  if (datos.estado && datos.estado !== 'TODOS') {
    condiciones.push({ estado: datos.estado });
  }

  const q = datos.q?.trim();
  if (q) {
    condiciones.push({
      OR: [
        { mensaje: { contains: q, mode: 'insensitive' } },
        { bicicletero: { nombre: { contains: q, mode: 'insensitive' } } },
        { bicicletero: { ubicacion: { contains: q, mode: 'insensitive' } } },
        { solicitadaPorUsuario: { nombre: { contains: q, mode: 'insensitive' } } },
        { solicitadaPorUsuario: { correo: { contains: q, mode: 'insensitive' } } },
        { solicitadaPorUsuario: { rut: { contains: q, mode: 'insensitive' } } },
        { guardiaAsignado: { is: { nombre: { contains: q, mode: 'insensitive' } } } },
        { guardiaAsignado: { is: { correo: { contains: q, mode: 'insensitive' } } } }
      ]
    });
  }

  const limite = datos.limite && datos.limite > 0 ? Math.min(datos.limite, 500) : undefined;
  const solicitudes = await solicitudGuardiaRepositorio.listar({
    where: condiciones.length ? { AND: condiciones } : {},
    limite
  });

  return solicitudes.map(mapearSolicitudGuardia);
};

export const notificarGuardiaSolicitud = async (datos: DatosNotificarGuardia) => {
  const efectos: EfectosDiferidos = [];
  const resultado = await solicitudGuardiaRepositorio.ejecutarEnTransaccion(async (db) => {
    const solicitud = await solicitudGuardiaRepositorio.buscarPorId(datos.solicitudId, db);

    if (!solicitud) {
      throw new ErrorHttp(404, 'Solicitud no encontrada');
    }

    const solicitudActualizada = await reiterarSolicitudAbierta(
      solicitud,
      datos.usuarioId,
      datos.rol,
      datos.mensaje,
      db,
      efectos
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
