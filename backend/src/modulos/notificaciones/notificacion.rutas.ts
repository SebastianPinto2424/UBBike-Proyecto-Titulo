import { Router } from 'express';
import { middlewareAutenticacion } from '../../comun/middlewares/autenticacion.middleware';
import {
  validarConsulta,
  validarCuerpo,
  validarParametros
} from '../../comun/middlewares/validacion.middleware';
import { esquemaParametroId } from '../../comun/utilidades/esquemas-comunes';
import {
  eliminarDispositivo,
  listarNotificaciones,
  marcarLeida,
  marcarTodas,
  registrarDispositivo
} from './notificacion.controlador';
import {
  esquemaConsultaNotificaciones,
  esquemaEliminarDispositivo,
  esquemaRegistrarDispositivo
} from './dispositivo.validacion';

const rutasNotificaciones = Router();

rutasNotificaciones.use(middlewareAutenticacion);
rutasNotificaciones.get('/', validarConsulta(esquemaConsultaNotificaciones), listarNotificaciones);
rutasNotificaciones.patch('/leidas', marcarTodas);
rutasNotificaciones.patch('/:id/leida', validarParametros(esquemaParametroId), marcarLeida);
rutasNotificaciones.post(
  '/dispositivos',
  validarCuerpo(esquemaRegistrarDispositivo),
  registrarDispositivo
);
rutasNotificaciones.delete(
  '/dispositivos',
  validarCuerpo(esquemaEliminarDispositivo),
  eliminarDispositivo
);

export { rutasNotificaciones };
