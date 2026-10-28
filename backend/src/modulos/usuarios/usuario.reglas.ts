import { ErrorHttp } from '../../comun/errores/error-http';
import { RolUsuario } from './rol-usuario';

const correoPorRol: Partial<Record<RolUsuario, { dominio: string; quien: string }>> = {
  [RolUsuario.ESTUDIANTE]: { dominio: '@alumnos.ubiobio.cl', quien: 'Un estudiante' },
  [RolUsuario.FUNCIONARIO]: { dominio: '@ubiobio.cl', quien: 'Un funcionario' },
  [RolUsuario.ADMIN_CENTRAL]: { dominio: '@ubiobio.cl', quien: 'Un administrador central' },
  [RolUsuario.ADMINISTRADOR]: { dominio: '@ubiobio.cl', quien: 'Un administrador' }
};

export const validarCorreoParaRol = (correo: string, rol: string) => {
  const regla = correoPorRol[rol as RolUsuario];
  if (regla && !correo.trim().toLowerCase().endsWith(regla.dominio)) {
    throw new ErrorHttp(400, `${regla.quien} debe usar un correo ${regla.dominio}`);
  }
};
