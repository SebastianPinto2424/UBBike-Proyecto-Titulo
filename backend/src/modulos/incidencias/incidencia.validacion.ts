import Joi from 'joi';
import {
  esquemaCursorPagina,
  esquemaIdentificador,
  esquemaLimitePagina,
  esquemaTextoBusqueda
} from '../../comun/utilidades/esquemas-comunes';
import { maximoFotosIncidencia, maximoLargoFotoIncidencia } from './foto-incidencia.servicio';
import { EstadoIncidencia } from './estado-incidencia';
import { TipoIncidencia } from './tipo-incidencia';

export const esquemaCrearIncidencia = Joi.object({
  bicicleteroId: Joi.string().uuid().required(),
  bicicletaId: Joi.string().uuid().allow('', null),
  tipo: Joi.string()
    .valid(...Object.values(TipoIncidencia))
    .default(TipoIncidencia.OTRO),
  descripcion: Joi.string().trim().min(8).max(1000).required(),
  fotos: Joi.array()
    .items(
      Joi.string()
        .trim()
        .max(maximoLargoFotoIncidencia)
        .pattern(/^data:image\/(jpeg|jpg|png|webp);base64,[A-Za-z0-9+/=]+$/)
        .messages({
          'string.pattern.base': 'La foto debe ser una imagen valida en formato JPG, PNG o WEBP',
          'string.max': 'La foto es muy pesada. El maximo permitido es 2 MB'
        })
    )
    .max(maximoFotosIncidencia)
    .default([])
    .messages({
      'array.max': `Puedes adjuntar hasta ${maximoFotosIncidencia} fotos por incidencia`
    })
});

export const esquemaActualizarEstadoIncidencia = Joi.object({
  estado: Joi.string()
    .valid(...Object.values(EstadoIncidencia))
    .required(),
  respuesta: Joi.when('estado', {
    is: Joi.valid(EstadoIncidencia.RESUELTA, EstadoIncidencia.DESCARTADA),
    then: Joi.string().trim().min(8).max(1000).required().messages({
      'any.required': 'Debes indicar una respuesta para cerrar la incidencia',
      'string.empty': 'Debes indicar una respuesta para cerrar la incidencia',
      'string.min': 'La respuesta debe explicar la resolución con al menos 8 caracteres'
    }),
    otherwise: Joi.string().trim().max(1000).allow('', null).optional()
  })
});

export const esquemaConsultaIncidencias = Joi.object({
  estado: Joi.string().valid(...Object.values(EstadoIncidencia), 'TODOS', 'ABIERTAS'),
  tipo: Joi.string().valid(...Object.values(TipoIncidencia), 'TODOS'),
  bicicleteroId: esquemaIdentificador,
  q: esquemaTextoBusqueda,
  cursor: esquemaCursorPagina,
  limite: esquemaLimitePagina
});
