import { ErrorHttp } from '../../../comun/errores/error-http';
import { RolUsuario } from '../../usuarios/rol-usuario';
import { EstadoSolicitudGuardia } from './estado-solicitud-guardia';
import type { SolicitudCompleta } from './solicitud-guardia.repositorio';

const segundosEsperaRecordatorio = 60;
export const rolesCentral: string[] = [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR];
export const rolesGestionSolicitudes: string[] = [
  RolUsuario.GUARDIA,
  RolUsuario.ADMIN_CENTRAL,
  RolUsuario.ADMINISTRADOR
];
export const estadosCerrados: EstadoSolicitudGuardia[] = [
  EstadoSolicitudGuardia.RESUELTA,
  EstadoSolicitudGuardia.CANCELADA
];
export const estadosSinRespuesta: EstadoSolicitudGuardia[] = [
  EstadoSolicitudGuardia.PENDIENTE,
  EstadoSolicitudGuardia.NOTIFICADA
];

export const impedirAtencionPropia = (guardiaId: string | undefined, solicitanteId: string) => {
  if (guardiaId === solicitanteId) {
    throw new ErrorHttp(
      403,
      'No puedes pedir atención en el bicicletero que gestionas. Si necesitas apoyo, avisa a central.'
    );
  }
};

export const calcularSegundosParaRecordatorio = (solicitud: SolicitudCompleta) => {
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

export const validarRecordatorioCentral = (solicitud: SolicitudCompleta, rol: string) => {
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

const cambiosPermitidosPorRol: Record<string, EstadoSolicitudGuardia[]> = {
  [RolUsuario.GUARDIA]: [EstadoSolicitudGuardia.EN_CAMINO, EstadoSolicitudGuardia.RESUELTA],
  [RolUsuario.ADMIN_CENTRAL]: [EstadoSolicitudGuardia.NOTIFICADA, EstadoSolicitudGuardia.CANCELADA],
  [RolUsuario.ADMINISTRADOR]: [EstadoSolicitudGuardia.NOTIFICADA, EstadoSolicitudGuardia.CANCELADA]
};

export const validarCambioDeEstado = (rol: string, estado: EstadoSolicitudGuardia) => {
  if ((cambiosPermitidosPorRol[rol] ?? []).includes(estado)) {
    return;
  }

  if (estado === EstadoSolicitudGuardia.RESUELTA) {
    throw new ErrorHttp(
      403,
      'Solo el guardia que atendió la solicitud puede marcarla como resuelta'
    );
  }

  if (estado === EstadoSolicitudGuardia.CANCELADA) {
    throw new ErrorHttp(403, 'Solo central o quien hizo la solicitud pueden cancelarla');
  }

  throw new ErrorHttp(403, 'No puedes cambiar la solicitud a ese estado');
};
