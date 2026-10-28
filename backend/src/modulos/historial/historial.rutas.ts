import { Router } from 'express';
import { middlewareAutenticacion } from '../../comun/middlewares/autenticacion.middleware';
import { validarConsulta } from '../../comun/middlewares/validacion.middleware';
import { listar, opciones, resumen, exportarExcel } from './historial.controlador';
import { esquemaConsultaHistorial } from './historial.validacion';

const rutasHistorial = Router();

rutasHistorial.use(middlewareAutenticacion);

rutasHistorial.get('/exportar-excel', validarConsulta(esquemaConsultaHistorial), exportarExcel);
rutasHistorial.get('/opciones', opciones);
rutasHistorial.get('/resumen', validarConsulta(esquemaConsultaHistorial), resumen);
rutasHistorial.get('/', validarConsulta(esquemaConsultaHistorial), listar);

export { rutasHistorial };
