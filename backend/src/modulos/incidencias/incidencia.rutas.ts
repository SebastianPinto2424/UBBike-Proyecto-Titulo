import { Router } from 'express';
import { middlewareAutenticacion } from '../../comun/middlewares/autenticacion.middleware';
import {
  validarConsulta,
  validarCuerpo,
  validarParametros
} from '../../comun/middlewares/validacion.middleware';
import { esquemaParametroId } from '../../comun/utilidades/esquemas-comunes';
import { actualizarEstado, crear, listar, recordar } from './incidencia.controlador';
import {
  esquemaActualizarEstadoIncidencia,
  esquemaConsultaIncidencias,
  esquemaCrearIncidencia
} from './incidencia.validacion';

const rutasIncidencias = Router();

rutasIncidencias.use(middlewareAutenticacion);
rutasIncidencias.get('/', validarConsulta(esquemaConsultaIncidencias), listar);
rutasIncidencias.post('/', validarCuerpo(esquemaCrearIncidencia), crear);
rutasIncidencias.post('/:id/recordar', validarParametros(esquemaParametroId), recordar);
rutasIncidencias.patch(
  '/:id/estado',
  validarParametros(esquemaParametroId),
  validarCuerpo(esquemaActualizarEstadoIncidencia),
  actualizarEstado
);

export { rutasIncidencias };
