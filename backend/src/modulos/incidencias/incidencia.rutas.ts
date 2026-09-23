import { Router } from 'express';
import { middlewareAutenticacion } from '../../comun/middlewares/autenticacion.middleware';
import { validarCuerpo } from '../../comun/middlewares/validar-cuerpo.middleware';
import { actualizarEstado, crear, listar, recordar } from './incidencia.controlador';
import { esquemaActualizarEstadoIncidencia, esquemaCrearIncidencia } from './incidencia.validacion';

const rutasIncidencias = Router();

rutasIncidencias.use(middlewareAutenticacion);
rutasIncidencias.get('/', listar);
rutasIncidencias.post('/', validarCuerpo(esquemaCrearIncidencia), crear);
rutasIncidencias.post('/:id/recordar', recordar);
rutasIncidencias.patch(
  '/:id/estado',
  validarCuerpo(esquemaActualizarEstadoIncidencia),
  actualizarEstado
);

export { rutasIncidencias };
