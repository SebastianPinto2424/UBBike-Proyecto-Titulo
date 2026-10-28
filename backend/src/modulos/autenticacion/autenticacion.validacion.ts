import Joi from 'joi';
import { validarRutChileno } from '../../comun/utilidades/rut';
import { NOMBRE_COMPLETO, validarNombreCompleto } from '../../comun/utilidades/nombre';

export const reglasNombre = {
  maximo: 120,
  patron: NOMBRE_COMPLETO
};

export const reglasContrasena = {
  minimo: 12,
  maximo: 72,
  patron: /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).+$/
};

const mensajeNombre = {
  'any.invalid': 'Ingresa dos nombres y dos apellidos (Nombre Nombre Apellido Apellido)'
};

const mensajeRut = {
  'any.invalid': 'RUT inválido. Usa el formato con guion: xx.xxx.xxx-x'
};

const mensajeCorreoInstitucional = {
  'any.invalid': 'Debes usar un correo @ubiobio.cl o @alumnos.ubiobio.cl'
};

const validarCorreoInstitucional = (valor: string, helpers: Joi.CustomHelpers) => {
  const correo = valor.toLowerCase();
  return correo.endsWith('@ubiobio.cl') || correo.endsWith('@alumnos.ubiobio.cl')
    ? correo
    : helpers.error('any.invalid');
};

export const esquemaNombre = Joi.string()
  .trim()
  .max(reglasNombre.maximo)
  .custom(validarNombreCompleto)
  .messages({
    ...mensajeNombre,
    'string.empty': 'Escribe tu nombre completo',
    'any.required': 'Escribe tu nombre completo',
    'string.max': 'El nombre no puede superar 120 caracteres'
  });

export const esquemaContrasena = Joi.string()
  .min(reglasContrasena.minimo)
  .max(reglasContrasena.maximo)
  .pattern(reglasContrasena.patron)
  .required()
  .messages({
    'string.empty': 'Escribe una contraseña',
    'any.required': 'Escribe una contraseña',
    'string.max': 'La contraseña no puede superar 72 caracteres',
    'string.min': 'La contraseña debe tener al menos 12 caracteres',
    'string.pattern.base': 'La contraseña debe incluir mayúscula, minúscula, número y símbolo'
  });

const esquemaCorreoInstitucional = Joi.string()
  .trim()
  .lowercase()
  .email()
  .max(160)
  .custom(validarCorreoInstitucional)
  .messages(mensajeCorreoInstitucional);

const esquemaCorreoRegistrado = Joi.string().trim().lowercase().email().max(160);

export const esquemaRegistro = Joi.object({
  nombre: esquemaNombre.required(),
  rut: Joi.string()
    .trim()
    .max(20)
    .custom(validarRutChileno)
    .required()
    .messages({
      ...mensajeRut,
      'string.empty': 'Escribe tu RUT',
      'any.required': 'Escribe tu RUT'
    }),
  correo: esquemaCorreoInstitucional.required(),
  contrasena: esquemaContrasena
});

const esquemaTokenEnlace = Joi.string().trim().max(255);

export const esquemaLogin = Joi.object({
  correo: Joi.string().trim().lowercase().email().max(160).required(),
  contrasena: Joi.string().max(reglasContrasena.maximo).required()
});

export const esquemaSolicitudCambioContrasena = Joi.object({
  correo: esquemaCorreoRegistrado.required()
});

export const esquemaReenviarVerificacion = Joi.object({
  correo: esquemaCorreoRegistrado.required()
});

export const esquemaVerificarCorreo = Joi.object({
  token: esquemaTokenEnlace.required()
});

export const esquemaCompletarRegistro = Joi.object({
  token: esquemaTokenEnlace.required(),
  nombre: esquemaNombre.required(),
  contrasena: esquemaContrasena
});

export const esquemaCambioContrasena = Joi.object({
  token: esquemaTokenEnlace.required(),
  contrasena: esquemaContrasena
});

export const esquemaCambioContrasenaSesion = Joi.object({
  contrasenaActual: Joi.string().max(reglasContrasena.maximo).required(),
  contrasenaNueva: esquemaContrasena
});

export const esquemaRefreshToken = Joi.object({
  usuarioId: Joi.string().uuid().required(),
  refreshToken: esquemaTokenEnlace.required()
});
