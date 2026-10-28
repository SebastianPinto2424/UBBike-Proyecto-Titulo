import { entorno } from '../../configuracion/entorno';
import { RolUsuario } from './rol-usuario';
import * as usuarioRepositorio from './usuario.repositorio';
import { crearUsuarioAdmin } from './usuario.servicio';

export const asegurarAdministradorInicial = async (): Promise<boolean> => {
  const { correo, nombre } = entorno.administradorInicial;
  if (!correo) {
    return false;
  }

  if (await usuarioRepositorio.buscarPorCorreo(correo)) {
    return false;
  }

  await crearUsuarioAdmin({ nombre, correo, rol: RolUsuario.ADMINISTRADOR });
  console.log(
    '[inicio] Administrador inicial creado; se envió el correo para definir su contraseña'
  );
  return true;
};
