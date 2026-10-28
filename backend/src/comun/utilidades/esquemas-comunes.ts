import Joi from 'joi';

export const esquemaIdentificador = Joi.string().uuid().messages({
  'string.guid': 'Identificador inválido',
  'string.base': 'Identificador inválido'
});

export const esquemaParametroId = Joi.object({
  id: esquemaIdentificador.required()
});

export const esquemaTextoBusqueda = Joi.string().trim().max(120).allow('').messages({
  'string.max': 'La búsqueda no puede superar 120 caracteres'
});

export const esquemaLimitePagina = Joi.number().integer().min(1).messages({
  'number.base': 'El límite debe ser un entero positivo',
  'number.integer': 'El límite debe ser un entero positivo',
  'number.min': 'El límite debe ser un entero positivo'
});

export const esquemaCursorPagina = Joi.string().uuid().messages({
  'string.guid': 'Cursor de paginación inválido'
});
