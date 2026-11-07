import { Router } from 'express';
import { middlewareAutenticacion } from '../../comun/middlewares/autenticacion.middleware';
import { autorizarRoles } from '../../comun/middlewares/autorizar-roles.middleware';
import { validarCuerpo, validarParametros } from '../../comun/middlewares/validacion.middleware';
import { esquemaParametroId } from '../../comun/utilidades/esquemas-comunes';
import { rolesConFuncionesDeUsuario, rolesQueValidanAccesos } from '../usuarios/permisos-rol';
import { consultarEstado, generar, liberar, validar } from './qr.controlador';
import { esquemaGenerarQr, esquemaValidarQr } from './qr.validacion';

const rutasQr = Router();

rutasQr.use(middlewareAutenticacion);
rutasQr.post(
  '/generar',
  autorizarRoles(...rolesConFuncionesDeUsuario),
  validarCuerpo(esquemaGenerarQr),
  generar
);
rutasQr.get(
  '/:id/estado',
  autorizarRoles(...rolesConFuncionesDeUsuario),
  validarParametros(esquemaParametroId),
  consultarEstado
);
rutasQr.post(
  '/validar',
  autorizarRoles(...rolesQueValidanAccesos),
  validarCuerpo(esquemaValidarQr),
  validar
);

rutasQr.post(
  '/liberar',
  autorizarRoles(...rolesQueValidanAccesos),
  validarCuerpo(esquemaValidarQr),
  liberar
);

export { rutasQr };
