import { Router } from 'express';
import { middlewareAutenticacion } from '../../comun/middlewares/autenticacion.middleware';
import { validarCuerpo } from '../../comun/middlewares/validar-cuerpo.middleware';
import {
  eliminarDispositivo,
  listarNotificaciones,
  marcarLeida,
  marcarTodas,
  registrarDispositivo
} from './notificacion.controlador';
import { esquemaEliminarDispositivo, esquemaRegistrarDispositivo } from './dispositivo.validacion';

const rutasNotificaciones = Router();

rutasNotificaciones.use(middlewareAutenticacion);
rutasNotificaciones.get('/', listarNotificaciones);
rutasNotificaciones.patch('/leidas', marcarTodas);
rutasNotificaciones.patch('/:id/leida', marcarLeida);
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
