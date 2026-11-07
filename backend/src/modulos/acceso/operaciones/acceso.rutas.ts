import { Router } from 'express';
import { middlewareAutenticacion } from '../../../comun/middlewares/autenticacion.middleware';
import { autorizarRoles } from '../../../comun/middlewares/autorizar-roles.middleware';
import { validarConsulta, validarCuerpo } from '../../../comun/middlewares/validacion.middleware';
import { rolesQueValidanAccesos } from '../../usuarios/permisos-rol';
import {
  buscarManual,
  confirmarAccesoQr,
  denegarAccesoQr,
  registrarManual
} from './acceso.controlador';
import {
  esquemaBuscarGestionManual,
  esquemaConfirmarQr,
  esquemaDenegarQr,
  esquemaGestionManual
} from './acceso.validacion';

const rutasAcceso = Router();

rutasAcceso.use(middlewareAutenticacion);
rutasAcceso.use(autorizarRoles(...rolesQueValidanAccesos));

rutasAcceso.post('/qr/confirmar', validarCuerpo(esquemaConfirmarQr), confirmarAccesoQr);
rutasAcceso.post('/qr/denegar', validarCuerpo(esquemaDenegarQr), denegarAccesoQr);
rutasAcceso.get('/manual/buscar', validarConsulta(esquemaBuscarGestionManual), buscarManual);
rutasAcceso.post('/manual', validarCuerpo(esquemaGestionManual), registrarManual);

export { rutasAcceso };
