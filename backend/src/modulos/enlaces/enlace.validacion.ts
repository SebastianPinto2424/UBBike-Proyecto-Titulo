import Joi from 'joi';
import {
  esquemaContrasena,
  esquemaNombre,
  reglasContrasena,
  reglasNombre
} from '../autenticacion/autenticacion.validacion';

export type ReglaCampo = {
  minimo?: number;
  maximo: number;
  patron: RegExp;
  normalizar: boolean;
  ayuda: string;
  mensajes: { obligatorio: string; maximo: string; formato: string };
};

export const reglasFormulario = {
  nombre: {
    maximo: reglasNombre.maximo,
    patron: reglasNombre.patron,
    normalizar: true,
    ayuda: 'Dos nombres y dos apellidos (ej: Nombre Nombre Apellido Apellido)',
    mensajes: {
      obligatorio: 'El nombre es obligatorio.',
      maximo: `Máximo ${reglasNombre.maximo} caracteres.`,
      formato: 'Ingresa dos nombres y dos apellidos (Nombre Nombre Apellido Apellido).'
    }
  },
  contrasena: {
    minimo: reglasContrasena.minimo,
    maximo: reglasContrasena.maximo,
    patron: reglasContrasena.patron,
    normalizar: false,
    ayuda: `Mínimo ${reglasContrasena.minimo} caracteres con mayúscula, minúscula, número y símbolo`,
    mensajes: {
      obligatorio: 'La contraseña es obligatoria.',
      maximo: `Máximo ${reglasContrasena.maximo} caracteres.`,
      formato: `Mínimo ${reglasContrasena.minimo} caracteres con mayúscula, minúscula, número y símbolo.`
    }
  }
} satisfies Record<string, ReglaCampo>;

export const reglaConfirmacion = {
  ayuda: 'Escribe la misma contraseña otra vez',
  mensaje: 'Las contraseñas no coinciden.'
};

const mensajesCampo = ({ mensajes }: ReglaCampo) => ({
  'any.required': mensajes.obligatorio,
  'string.empty': mensajes.obligatorio,
  'string.base': mensajes.formato,
  'string.max': mensajes.maximo,
  'string.min': mensajes.formato,
  'string.pattern.base': mensajes.formato,
  'any.invalid': mensajes.formato
});

const campoContrasena = esquemaContrasena.messages(mensajesCampo(reglasFormulario.contrasena));

const campoConfirmacion = Joi.string().valid(Joi.ref('contrasena')).required().messages({
  'any.only': reglaConfirmacion.mensaje,
  'any.required': reglaConfirmacion.mensaje,
  'string.empty': reglaConfirmacion.mensaje,
  'string.base': reglaConfirmacion.mensaje
});

export const esquemaFormularioContrasena = Joi.object({
  contrasena: campoContrasena,
  confirmacion: campoConfirmacion
});

export const esquemaFormularioRegistro = Joi.object({
  nombre: esquemaNombre.required().messages(mensajesCampo(reglasFormulario.nombre)),
  contrasena: campoContrasena,
  confirmacion: campoConfirmacion
});
