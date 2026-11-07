import { Router } from 'express';
import { middlewareAutenticacion } from '../../comun/middlewares/autenticacion.middleware';
import { autorizarRoles } from '../../comun/middlewares/autorizar-roles.middleware';
import { validarCuerpo, validarParametros } from '../../comun/middlewares/validacion.middleware';
import { esquemaParametroId } from '../../comun/utilidades/esquemas-comunes';
import { rolesConFuncionesDeUsuario } from '../usuarios/permisos-rol';
import {
  activar,
  actualizar,
  crear,
  desactivar,
  eliminar,
  listar,
  obtenerActiva
} from './bicicleta.controlador';
import { esquemaActualizarBicicleta, esquemaCrearBicicleta } from './bicicleta.validacion';

const rutasBicicletas = Router();

rutasBicicletas.use(middlewareAutenticacion, autorizarRoles(...rolesConFuncionesDeUsuario));
rutasBicicletas.get('/', listar);
rutasBicicletas.get('/activa', obtenerActiva);
rutasBicicletas.post('/', validarCuerpo(esquemaCrearBicicleta), crear);
rutasBicicletas.patch(
  '/:id',
  validarParametros(esquemaParametroId),
  validarCuerpo(esquemaActualizarBicicleta),
  actualizar
);
rutasBicicletas.delete('/:id', validarParametros(esquemaParametroId), eliminar);
rutasBicicletas.patch('/:id/activar', validarParametros(esquemaParametroId), activar);
rutasBicicletas.patch('/:id/desactivar', validarParametros(esquemaParametroId), desactivar);

export { rutasBicicletas };
