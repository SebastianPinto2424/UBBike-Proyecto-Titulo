import { Router } from 'express';
import { middlewareAutenticacion } from '../../../comun/middlewares/autenticacion.middleware';
import { autorizarRoles } from '../../../comun/middlewares/autorizar-roles.middleware';
import { validarCuerpo } from '../../../comun/middlewares/validacion.middleware';
import { RolUsuario } from '../../usuarios/rol-usuario';
import {
  liberarMiBicicletero,
  listarGuardias,
  obtenerMiBicicletero,
  seleccionarMiBicicletero
} from './asignacion-guardia.controlador';
import { esquemaSeleccionarBicicleteroGuardia } from './asignacion-guardia.validacion';

const rutasAsignacionGuardia = Router();

const soloGuardia = autorizarRoles(RolUsuario.GUARDIA);

rutasAsignacionGuardia.use(middlewareAutenticacion);
rutasAsignacionGuardia.get(
  '/',
  autorizarRoles(RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR),
  listarGuardias
);
rutasAsignacionGuardia.get('/me/bicicletero', soloGuardia, obtenerMiBicicletero);
rutasAsignacionGuardia.patch(
  '/me/bicicletero',
  soloGuardia,
  validarCuerpo(esquemaSeleccionarBicicleteroGuardia),
  seleccionarMiBicicletero
);
rutasAsignacionGuardia.delete('/me/bicicletero', soloGuardia, liberarMiBicicletero);

export { rutasAsignacionGuardia };
