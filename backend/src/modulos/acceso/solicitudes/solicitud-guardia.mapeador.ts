import { EstadoSolicitudGuardia } from './estado-solicitud-guardia';
import type { SolicitudCompleta } from './solicitud-guardia.repositorio';
import { calcularSegundosParaRecordatorio } from './solicitud-guardia.reglas';

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

export const tituloSolicitudParaUsuario = (estado: EstadoSolicitudGuardia) => {
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

export const mensajeSolicitudParaUsuario = (
  estado: EstadoSolicitudGuardia,
  bicicleteroNombre: string,
  motivoCentral?: string | null
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

  return motivoCentral ? `${base} Motivo de central: ${motivoCentral}` : base;
};

const quienCerro = (solicitud: SolicitudCompleta) => {
  if (!solicitud.cerradaPorUsuarioId) {
    return null;
  }
  if (solicitud.cerradaPorUsuarioId === solicitud.solicitadaPorUsuario.id) {
    return 'SOLICITANTE';
  }
  if (solicitud.cerradaPorUsuarioId === solicitud.guardiaAsignado?.id) {
    return 'GUARDIA';
  }
  return 'CENTRAL';
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

export const mapearSolicitudGuardia = (solicitud: SolicitudCompleta) => {
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
    motivoCierre: solicitud.motivoCierre,
    cerradaPor: quienCerro(solicitud),
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
