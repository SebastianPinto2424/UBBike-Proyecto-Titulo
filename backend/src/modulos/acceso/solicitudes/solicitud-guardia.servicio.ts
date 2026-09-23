import { ErrorHttp } from '../../../comun/errors/error-http';
import { bloquearClave, bloquearFila } from '../../../comun/utils/bloqueos';
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
};

const segundosEsperaRecordatorio = 60;
const rolesCentral: string[] = [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR];
const rolesGestionSolicitudes: string[] = [
  RolUsuario.GUARDIA,
  RolUsuario.ADMIN_CENTRAL,
  RolUsuario.ADMINISTRADOR
];
const estadosCerrados: EstadoSolicitudGuardia[] = [
  EstadoSolicitudGuardia.RESUELTA,
  EstadoSolicitudGuardia.CANCELADA
];

const etiquetaEstadoSolicitud = (estado: EstadoSolicitudGuardia) => {
  switch (estado) {
    case EstadoSolicitudGuardia.PENDIENTE:
      return 'pendiente';
    case EstadoSolicitudGuardia.NOTIFICADA:
      return 'guardia notificado';
    case EstadoSolicitudGuardia.EN_CAMINO:
      return 'guardia en camino';
    case EstadoSolicitudGuardia.RESUELTA:
      return 'resuelta';
    case EstadoSolicitudGuardia.CANCELADA:
      return 'cancelada';
    default:
      return estado;
  }
};

const tituloSolicitudParaUsuario = (estado: EstadoSolicitudGuardia) => {
  switch (estado) {
    case EstadoSolicitudGuardia.EN_CAMINO:
      return 'Guardia en camino';
    case EstadoSolicitudGuardia.RESUELTA:
      return 'Solicitud resuelta';
    case EstadoSolicitudGuardia.CANCELADA:
      return 'Solicitud cancelada';
    default:
      return 'Solicitud actualizada';
  }
};

const mensajeSolicitudParaUsuario = (
  estado: EstadoSolicitudGuardia,
  bicicleteroNombre: string,
  notaCierreCentral?: string | null
) => {
  const base = (() => {
    switch (estado) {
      case EstadoSolicitudGuardia.EN_CAMINO:
        return `El guardia va en camino a ${bicicleteroNombre}.`;
      case EstadoSolicitudGuardia.RESUELTA:
        return `Tu solicitud en ${bicicleteroNombre} fue atendida.`;
      case EstadoSolicitudGuardia.CANCELADA:
        return `Tu solicitud en ${bicicleteroNombre} fue cancelada.`;
      default:
        return `${bicicleteroNombre}: ${etiquetaEstadoSolicitud(estado)}.`;
    }
  })();

  return notaCierreCentral ? `${base} Nota de central: ${notaCierreCentral}` : base;
};

const mapearUsuarioSolicitud = (
  usuario: SolicitudCompleta['solicitadaPorUsuario'] | SolicitudCompleta['guardiaAsignado']
) => {
  if (!usuario) {
    return null;
  }

  return {
    id: usuario.id,
    nombre: usuario.nombre,
    correo: usuario.correo,
    rut: usuario.rut,
    rol: usuario.rol
  };
};

const calcularSegundosParaRecordatorio = (solicitud: SolicitudCompleta) => {
  if (
    solicitud.respondidaPorGuardiaEn ||
    solicitud.estado === EstadoSolicitudGuardia.EN_CAMINO ||
    estadosCerrados.includes(solicitud.estado)
  ) {
    return null;
  }

  const base = solicitud.notificadaGuardiaEn ?? solicitud.creadaEn;
  const transcurridos = Math.floor((Date.now() - base.getTime()) / 1000);
  return Math.max(segundosEsperaRecordatorio - transcurridos, 0);
};

const mapearSolicitudGuardia = (solicitud: SolicitudCompleta) => {
  const segundosParaNotificarGuardia = calcularSegundosParaRecordatorio(solicitud);

  return {
    id: solicitud.id,
    tipo: solicitud.tipo,
    estado: solicitud.estado,
    mensaje: solicitud.mensaje,
    creadaEn: solicitud.creadaEn,
    notificadaGuardiaEn: solicitud.notificadaGuardiaEn,
    ultimaNotificacionUsuarioEn: solicitud.ultimaNotificacionUsuarioEn,
    notificacionesGuardia: solicitud.notificacionesGuardia,
    respondidaPorGuardiaEn: solicitud.respondidaPorGuardiaEn,
    enCaminoEn: solicitud.enCaminoEn,
    resueltaEn: solicitud.resueltaEn,
    notaCierreCentral: solicitud.notaCierreCentral,
    puedeNotificarGuardia: Boolean(solicitud.guardiaAsignado) && segundosParaNotificarGuardia === 0,
    segundosParaNotificarGuardia,
    bicicletero: {
      id: solicitud.bicicletero.id,
      nombre: solicitud.bicicletero.nombre,
      ubicacion: solicitud.bicicletero.ubicacion
    },
    solicitante: mapearUsuarioSolicitud(solicitud.solicitadaPorUsuario),
    guardiaAsignado: mapearUsuarioSolicitud(solicitud.guardiaAsignado),
    guardiasAsignados: solicitud.guardiaAsignado
      ? [mapearUsuarioSolicitud(solicitud.guardiaAsignado)]
      : []
  };
};

const validarRecordatorioCentral = (solicitud: SolicitudCompleta, rol: string) => {
  if (!rolesCentral.includes(rol)) {
    throw new ErrorHttp(403, 'Solo central puede reenviar la notificación al guardia');
  }

  if (!solicitud.guardiaAsignado) {
    throw new ErrorHttp(409, 'No hay guardia asignado para este bicicletero');
  }

  if (solicitud.respondidaPorGuardiaEn || solicitud.estado === EstadoSolicitudGuardia.EN_CAMINO) {
    throw new ErrorHttp(409, 'El guardia ya respondió esta solicitud');
  }

  if (estadosCerrados.includes(solicitud.estado)) {
    throw new ErrorHttp(409, 'La solicitud ya está cerrada');
  }

  const segundosRestantes = calcularSegundosParaRecordatorio(solicitud);

  if (segundosRestantes !== null && segundosRestantes > 0) {
    throw new ErrorHttp(409, `Central podrá notificar nuevamente en ${segundosRestantes} segundos`);
  }
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

  if (datos.rol === RolUsuario.GUARDIA) {
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
    const cierreForzadoPorCentral =
      rolesCentral.includes(rol) &&
      (estado === EstadoSolicitudGuardia.RESUELTA || estado === EstadoSolicitudGuardia.CANCELADA);

    if (cierreForzadoPorCentral && !notaLimpia) {
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
        notaCierreCentral: cierreForzadoPorCentral ? notaLimpia : solicitud.notaCierreCentral
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
            cierreForzadoPorCentral ? notaLimpia : null
          ),
          tipo: TipoNotificacion.SOLICITUD_GUARDIA,
          datos: { solicitudId: solicitud.id, estado }
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
          cierreForzadoPorCentral,
          notaCierreCentral: cierreForzadoPorCentral ? notaLimpia : undefined
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
