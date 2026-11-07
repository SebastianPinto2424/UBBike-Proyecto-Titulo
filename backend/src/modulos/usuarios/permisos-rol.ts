import { RolUsuario } from './rol-usuario';

export const rolesConFuncionesDeUsuario: string[] = [
  RolUsuario.ESTUDIANTE,
  RolUsuario.FUNCIONARIO,
  RolUsuario.GUARDIA,
  RolUsuario.ADMIN_CENTRAL,
  RolUsuario.ADMINISTRADOR
];

export const rolesQueValidanAccesos: string[] = [RolUsuario.GUARDIA, RolUsuario.ADMINISTRADOR];
