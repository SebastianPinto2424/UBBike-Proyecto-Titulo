import { EventosTiempoReal, emitirTiempoReal, salaRol } from '../../tiempo-real/tiempo-real';
import { RolUsuario } from './rol-usuario';

export const emitirCambioUsuarios = () =>
  emitirTiempoReal(
    [salaRol(RolUsuario.ADMINISTRADOR), salaRol(RolUsuario.ADMIN_CENTRAL)],
    EventosTiempoReal.USUARIO
  );
