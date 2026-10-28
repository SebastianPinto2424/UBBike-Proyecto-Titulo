import Joi from 'joi';
import {
  esquemaIdentificador,
  esquemaLimitePagina,
  esquemaTextoBusqueda
} from '../../comun/utilidades/esquemas-comunes';
import { EstadoMovimiento } from './estado-movimiento';
import { TipoMovimiento } from './tipo-movimiento';

const esquemaFechaFiltro = Joi.string()
  .trim()
  .pattern(/^\d{4}-\d{2}-\d{2}(T[\d:.]+(Z|[+-]\d{2}:\d{2})?)?$/)
  .messages({ 'string.pattern.base': 'Filtro de fecha inválido' });

export const esquemaConsultaHistorial = Joi.object({
  q: esquemaTextoBusqueda,
  periodo: Joi.string().valid('DIA', 'SEMANA', 'MES', 'ANIO'),
  desde: esquemaFechaFiltro,
  hasta: esquemaFechaFiltro,
  tipo: Joi.string().valid(...Object.values(TipoMovimiento), 'TODOS'),
  estado: Joi.string().valid(...Object.values(EstadoMovimiento), 'TODOS'),
  origen: Joi.string().valid('QR', 'MANUAL', 'TODOS'),
  bicicleteroId: esquemaIdentificador,
  guardiaId: esquemaIdentificador,
  limit: esquemaLimitePagina.max(100000),
  page: Joi.number().integer().min(1).messages({
    'number.base': 'La página debe ser un entero positivo',
    'number.integer': 'La página debe ser un entero positivo',
    'number.min': 'La página debe ser un entero positivo'
  })
});
