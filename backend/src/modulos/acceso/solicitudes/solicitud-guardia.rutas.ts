import { Router } from 'express';
import { middlewareAutenticacion } from '../../../comun/middlewares/autenticacion.middleware';
import {
  validarConsulta,
  validarCuerpo,
  validarParametros
} from '../../../comun/middlewares/validacion.middleware';
import { esquemaParametroId } from '../../../comun/utilidades/esquemas-comunes';
import {
  actualizarEstado,
  cancelar,
  crear,
  listar,
  notificarGuardia
} from './solicitud-guardia.controlador';
import {
  esquemaActualizarEstadoSolicitudGuardia,
  esquemaCancelarSolicitudGuardia,
  esquemaConsultaSolicitudesGuardia,
  esquemaCrearSolicitudGuardia,
  esquemaNotificarGuardiaSolicitud
} from './solicitud-guardia.validacion';

const rutasSolicitudesGuardia = Router();

rutasSolicitudesGuardia.use(middlewareAutenticacion);
rutasSolicitudesGuardia.get('/', validarConsulta(esquemaConsultaSolicitudesGuardia), listar);
rutasSolicitudesGuardia.post('/', validarCuerpo(esquemaCrearSolicitudGuardia), crear);
rutasSolicitudesGuardia.post(
  '/:id/notificar-guardia',
  validarParametros(esquemaParametroId),
  validarCuerpo(esquemaNotificarGuardiaSolicitud),
  notificarGuardia
);
rutasSolicitudesGuardia.patch(
  '/:id/estado',
  validarParametros(esquemaParametroId),
  validarCuerpo(esquemaActualizarEstadoSolicitudGuardia),
  actualizarEstado
);
rutasSolicitudesGuardia.post(
  '/:id/cancelar',
  validarParametros(esquemaParametroId),
  validarCuerpo(esquemaCancelarSolicitudGuardia),
  cancelar
);

export { rutasSolicitudesGuardia };
