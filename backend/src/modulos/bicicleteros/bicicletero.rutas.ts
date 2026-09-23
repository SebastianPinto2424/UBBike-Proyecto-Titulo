import { Router } from 'express';
import { middlewareAutenticacion } from '../../comun/middlewares/autenticacion.middleware';
import { autorizarRoles } from '../../comun/middlewares/autorizar-roles.middleware';
import { validarCuerpo } from '../../comun/middlewares/validar-cuerpo.middleware';
import { RolUsuario } from '../usuarios/rol-usuario';
import { actualizar, crear, eliminar, listar } from './bicicletero.controlador';
import { esquemaActualizarBicicletero, esquemaCrearBicicletero } from './bicicletero.validacion';

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
  validarCuerpo(esquemaActualizarBicicletero),
  actualizar
);
rutasBicicleteros.delete(
  '/:id',
  middlewareAutenticacion,
  autorizarRoles(RolUsuario.ADMINISTRADOR),
  eliminar
);

export { rutasBicicleteros };
