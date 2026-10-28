import Joi from 'joi';
import { esquemaCursorPagina, esquemaLimitePagina } from '../../comun/utilidades/esquemas-comunes';

export const esquemaRegistrarDispositivo = Joi.object({
  token: Joi.string().trim().min(20).max(255).required(),
  plataforma: Joi.string().trim().valid('android', 'ios', 'web').default('android')
});

export const esquemaEliminarDispositivo = Joi.object({
  token: Joi.string().trim().min(20).max(255).required()
});

export const esquemaConsultaNotificaciones = Joi.object({
  cursor: esquemaCursorPagina,
  limite: esquemaLimitePagina,
  soloNoLeidas: Joi.boolean()
});
