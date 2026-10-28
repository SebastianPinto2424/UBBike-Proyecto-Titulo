import Joi from 'joi';

const validarParCoordenadas = (valor: Record<string, unknown>, helpers: Joi.CustomHelpers) => {
  if ((valor.latitud === null) !== (valor.longitud === null)) {
    return helpers.error('any.custom');
  }
  return valor;
};

const esquemaNombreBicicletero = Joi.string()
  .trim()
  .min(3)
  .max(120)
  .pattern(/[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]/)
  .messages({ 'string.pattern.base': 'El nombre debe incluir texto, no solo símbolos' });

export const esquemaCrearBicicletero = Joi.object({
  nombre: esquemaNombreBicicletero.required(),
  ubicacion: Joi.string().trim().min(3).max(255).required(),
  capacidad: Joi.number().integer().min(1).max(1000).default(80),
  latitud: Joi.number().min(-90).max(90).allow(null),
  longitud: Joi.number().min(-180).max(180).allow(null)
})
  .and('latitud', 'longitud')
  .custom(validarParCoordenadas)
  .messages({
    'object.and': 'Indica latitud y longitud juntas, o ninguna de las dos',
    'any.custom': 'Latitud y longitud deben ser ambas numéricas o ambas nulas'
  });

export const esquemaActualizarBicicletero = Joi.object({
  nombre: esquemaNombreBicicletero,
  ubicacion: Joi.string().trim().min(3).max(255),
  capacidad: Joi.number().integer().min(1).max(1000),
  latitud: Joi.number().min(-90).max(90).allow(null),
  longitud: Joi.number().min(-180).max(180).allow(null)
})
  .and('latitud', 'longitud')
  .custom(validarParCoordenadas)
  .min(1)
  .messages({
    'object.and': 'Indica latitud y longitud juntas, o ninguna de las dos',
    'any.custom': 'Latitud y longitud deben ser ambas numéricas o ambas nulas'
  });

export const esquemaAsignarGuardia = Joi.object({
  guardiaId: Joi.string().uuid().required()
});
