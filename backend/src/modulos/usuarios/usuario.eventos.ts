import {
  EventosTiempoReal,
  cerrarSesionesTiempoReal,
  emitirTiempoReal,
  salaRol,
  type MotivoCierreSesion
} from '../../tiempo-real/tiempo-real';
import { RolUsuario } from './rol-usuario';

export const emitirCambioUsuarios = () =>
  emitirTiempoReal(
    [salaRol(RolUsuario.ADMINISTRADOR), salaRol(RolUsuario.ADMIN_CENTRAL)],
    EventosTiempoReal.USUARIO
  );

export const cerrarSesionesUsuario = (usuarioId: string, motivo: MotivoCierreSesion) =>
  cerrarSesionesTiempoReal(usuarioId, motivo);
