import Joi from 'joi';
import { EstadoSolicitudGuardia } from './estado-solicitud-guardia';
import { TipoSolicitudGuardia } from './tipo-solicitud-guardia';

export const esquemaCrearSolicitudGuardia = Joi.object({
  bicicleteroId: Joi.string().uuid().required(),
  tipo: Joi.string()
    .valid(...Object.values(TipoSolicitudGuardia))
    .required(),
  mensaje: Joi.string().trim().max(600).allow('', null)
});

export const esquemaActualizarEstadoSolicitudGuardia = Joi.object({
  estado: Joi.string()
    .valid(...Object.values(EstadoSolicitudGuardia))
    .required(),
  nota: Joi.string().trim().max(600).allow('', null)
});

export const esquemaNotificarGuardiaSolicitud = Joi.object({
  mensaje: Joi.string().trim().max(600).allow('', null).optional()
}).default({});
