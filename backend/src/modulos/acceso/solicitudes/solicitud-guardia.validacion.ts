import Joi from 'joi';
import {
  esquemaAlcanceConsulta,
  esquemaLimitePagina,
  esquemaTextoBusqueda
} from '../../../comun/utilidades/esquemas-comunes';
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
  nota: Joi.when('estado', {
    is: EstadoSolicitudGuardia.CANCELADA,
    then: Joi.string().trim().min(3).max(600).allow('', null).messages({
      'string.min': 'El motivo del cierre debe tener al menos 3 caracteres'
    }),
    otherwise: Joi.string().trim().max(600).allow('', null)
  })
});

export const esquemaNotificarGuardiaSolicitud = Joi.object({
  mensaje: Joi.string().trim().max(600).allow('', null).optional()
}).default({});

export const esquemaCancelarSolicitudGuardia = Joi.object({
  motivo: Joi.string().trim().min(3).max(200).required()
}).required();

export const esquemaConsultaSolicitudesGuardia = Joi.object({
  estado: Joi.string().valid(...Object.values(EstadoSolicitudGuardia), 'TODOS'),
  q: esquemaTextoBusqueda,
  limite: esquemaLimitePagina,
  alcance: esquemaAlcanceConsulta
});
