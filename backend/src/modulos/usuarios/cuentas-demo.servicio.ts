import { correosUsuariosDemo } from '../../configuracion/datos-iniciales';
import { entorno } from '../../configuracion/entorno';
import * as usuarioRepositorio from './usuario.repositorio';

export const quitarUsuariosDemo = async (): Promise<number> => {
  if (entorno.datosDemo.habilitados) {
    throw new Error(
      'Primero deja SEED_DEMO_DATA=false; si no, las cuentas demo vuelven al reiniciar'
    );
  }

  const administradoresPropios =
    await usuarioRepositorio.contarAdministradoresSinCorreos(correosUsuariosDemo);
  if (administradoresPropios === 0) {
    throw new Error(
      'No hay otro administrador activo: configura ADMIN_INICIAL_CORREO y define su contraseña antes'
    );
  }

  return usuarioRepositorio.desactivarCuentasPorCorreo(correosUsuariosDemo);
};
