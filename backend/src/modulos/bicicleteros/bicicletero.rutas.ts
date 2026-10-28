import { Router } from 'express';
import { middlewareAutenticacion } from '../../comun/middlewares/autenticacion.middleware';
import { autorizarRoles } from '../../comun/middlewares/autorizar-roles.middleware';
import { validarCuerpo, validarParametros } from '../../comun/middlewares/validacion.middleware';
import { esquemaParametroId } from '../../comun/utilidades/esquemas-comunes';
import { RolUsuario } from '../usuarios/rol-usuario';
import {
  actualizar,
  asignarGuardia,
  crear,
  eliminar,
  liberarGuardia,
  listar
} from './bicicletero.controlador';
import {
  esquemaActualizarBicicletero,
  esquemaAsignarGuardia,
  esquemaCrearBicicletero
} from './bicicletero.validacion';

const rutasBicicleteros = Router();

rutasBicicleteros.get('/', middlewareAutenticacion, listar);
rutasBicicleteros.post(
  '/',
  middlewareAutenticacion,
  autorizarRoles(RolUsuario.ADMINISTRADOR),
  validarCuerpo(esquemaCrearBicicletero),
  crear
);
rutasBicicleteros.patch(
  '/:id',
  middlewareAutenticacion,
  autorizarRoles(RolUsuario.ADMINISTRADOR),
  validarParametros(esquemaParametroId),
  validarCuerpo(esquemaActualizarBicicletero),
  actualizar
);
rutasBicicleteros.delete(
  '/:id',
  middlewareAutenticacion,
  autorizarRoles(RolUsuario.ADMINISTRADOR),
  validarParametros(esquemaParametroId),
  eliminar
);
rutasBicicleteros.post(
  '/:id/guardia',
  middlewareAutenticacion,
  autorizarRoles(RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR),
  validarParametros(esquemaParametroId),
  validarCuerpo(esquemaAsignarGuardia),
  asignarGuardia
);
rutasBicicleteros.delete(
  '/:id/guardia',
  middlewareAutenticacion,
  autorizarRoles(RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR),
  validarParametros(esquemaParametroId),
  liberarGuardia
);

export { rutasBicicleteros };
