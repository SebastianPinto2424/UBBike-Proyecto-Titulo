import Joi from 'joi';
import { RolUsuario } from './rol-usuario';
import { validarRutChileno } from '../../comun/utilidades/rut';
import { esquemaTextoBusqueda } from '../../comun/utilidades/esquemas-comunes';
import { esquemaContrasena, esquemaNombre } from '../autenticacion/autenticacion.validacion';

const esquemaNombreUsuario = esquemaNombre.messages({
  'string.empty': 'El nombre es obligatorio',
  'any.required': 'El nombre es obligatorio'
});

const esquemaCorreoUsuario = Joi.string().trim().lowercase().email().max(160).messages({
  'string.empty': 'El correo es obligatorio',
  'any.required': 'El correo es obligatorio',
  'string.email': 'Ingresa un correo válido',
  'string.max': 'El correo no puede superar 160 caracteres'
});

const esquemaRutUsuario = Joi.string().trim().max(20).custom(validarRutChileno).messages({
  'string.empty': 'El RUT es obligatorio',
  'any.required': 'El RUT es obligatorio',
  'any.invalid': 'RUT inválido. Usa el formato con guion: xx.xxx.xxx-x'
});

const esquemaRol = Joi.string()
  .trim()
  .uppercase()
  .valid(...Object.values(RolUsuario))
  .messages({ 'any.only': 'Rol inválido' });

export const esquemaCrearUsuario = Joi.object({
  nombre: esquemaNombreUsuario.required(),
  correo: esquemaCorreoUsuario.required(),
  rut: esquemaRutUsuario.required(),
  rol: esquemaRol.required(),
  contrasena: esquemaContrasena.optional()
});

export const esquemaActualizarPermisosUsuario = Joi.object({
  nombre: esquemaNombreUsuario.optional(),
  correo: esquemaCorreoUsuario.optional(),
  rut: esquemaRutUsuario.optional(),
  rol: esquemaRol.optional(),
  cuentaActiva: Joi.boolean().optional()
}).min(1);

export const esquemaConsultaUsuarios = Joi.object({
  q: esquemaTextoBusqueda,
  rol: esquemaRol,
  cuentaActiva: Joi.boolean(),
  correoVerificado: Joi.boolean()
});
