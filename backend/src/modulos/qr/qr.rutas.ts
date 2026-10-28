import { Router } from 'express';
import { middlewareAutenticacion } from '../../comun/middlewares/autenticacion.middleware';
import { autorizarRoles } from '../../comun/middlewares/autorizar-roles.middleware';
import { validarCuerpo, validarParametros } from '../../comun/middlewares/validacion.middleware';
import { esquemaParametroId } from '../../comun/utilidades/esquemas-comunes';
import { RolUsuario } from '../usuarios/rol-usuario';
import { consultarEstado, generar, liberar, validar } from './qr.controlador';
import { esquemaGenerarQr, esquemaValidarQr } from './qr.validacion';

const rutasQr = Router();

rutasQr.use(middlewareAutenticacion);
rutasQr.post('/generar', validarCuerpo(esquemaGenerarQr), generar);
rutasQr.get('/:id/estado', validarParametros(esquemaParametroId), consultarEstado);
rutasQr.post(
  '/validar',
  autorizarRoles(RolUsuario.GUARDIA, RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR),
  validarCuerpo(esquemaValidarQr),
  validar
);

rutasQr.post(
  '/liberar',
  autorizarRoles(RolUsuario.GUARDIA, RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR),
  validarCuerpo(esquemaValidarQr),
  liberar
);

export { rutasQr };
