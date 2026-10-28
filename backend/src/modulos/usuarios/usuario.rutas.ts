import { Router } from 'express';
import { middlewareAutenticacion } from '../../comun/middlewares/autenticacion.middleware';
import { autorizarRoles } from '../../comun/middlewares/autorizar-roles.middleware';
import {
  validarConsulta,
  validarCuerpo,
  validarParametros
} from '../../comun/middlewares/validacion.middleware';
import { esquemaParametroId } from '../../comun/utilidades/esquemas-comunes';
import {
  actualizarPermisos,
  crear,
  eliminar,
  listar,
  reenviarAcceso,
  reenviarVerificacion
} from './usuario.controlador';
import { RolUsuario } from './rol-usuario';
import {
  esquemaActualizarPermisosUsuario,
  esquemaConsultaUsuarios,
  esquemaCrearUsuario
} from './usuario.validacion';

const rutasUsuarios = Router();

rutasUsuarios.use(middlewareAutenticacion);
rutasUsuarios.use(autorizarRoles(RolUsuario.ADMINISTRADOR));

rutasUsuarios.get('/', validarConsulta(esquemaConsultaUsuarios), listar);
rutasUsuarios.post('/', validarCuerpo(esquemaCrearUsuario), crear);
rutasUsuarios.patch(
  '/:id/permisos',
  validarParametros(esquemaParametroId),
  validarCuerpo(esquemaActualizarPermisosUsuario),
  actualizarPermisos
);
rutasUsuarios.post('/:id/reenviar-acceso', validarParametros(esquemaParametroId), reenviarAcceso);
rutasUsuarios.post(
  '/:id/reenviar-verificacion',
  validarParametros(esquemaParametroId),
  reenviarVerificacion
);
rutasUsuarios.delete('/:id', validarParametros(esquemaParametroId), eliminar);

export { rutasUsuarios };
