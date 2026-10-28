import Joi from 'joi';
import { TipoMovimiento } from '../../historial/tipo-movimiento';
import {
  esquemaAroBicicleta,
  esquemaColorBicicleta,
  esquemaDescripcionBicicleta,
  esquemaFotoBicicleta,
  esquemaMarcaBicicleta,
  esquemaModeloBicicleta,
  esquemaNumeroSerieBicicleta
} from '../../bicicletas/bicicleta.validacion';
import { validarRutChileno } from '../../../comun/utilidades/rut';
import { esquemaTokenQr } from '../../qr/qr.validacion';

const esquemaCorreoGestionManual = Joi.string().trim().lowercase().email().max(160).messages({
  'string.email': 'Ingresa un correo válido',
  'string.max': 'El correo no puede superar 160 caracteres'
});

export const esquemaConfirmarQr = Joi.object({
  token: esquemaTokenQr.required(),
  bicicleteroId: Joi.string().uuid().optional(),
  comentario: Joi.string().trim().max(600).allow('', null).optional()
});

export const esquemaDenegarQr = Joi.object({
  token: esquemaTokenQr.required(),
  motivo: Joi.string().trim().min(3).max(600).required(),
  bicicleteroId: Joi.string().uuid().optional()
});

export const esquemaBuscarGestionManual = Joi.object({
  correo: Joi.string().trim().lowercase().max(160),
  rut: Joi.string().trim().max(20)
})
  .or('correo', 'rut')
  .messages({ 'object.missing': 'Debes indicar correo o RUT para buscar coincidencias' });

export const esquemaGestionManual = Joi.object({
  nombre: Joi.string().trim().min(3).max(120).optional(),
  correo: esquemaCorreoGestionManual.optional(),
  rut: Joi.string().trim().max(20).custom(validarRutChileno).optional().messages({
    'any.invalid': 'RUT inválido. Usa el formato con guion: xx.xxx.xxx-x'
  }),
  bicicletaId: Joi.string().uuid().optional(),
  bicicletaDescripcion: esquemaDescripcionBicicleta.optional(),
  bicicletaMarca: esquemaMarcaBicicleta.optional(),
  bicicletaModelo: esquemaModeloBicicleta.optional(),
  bicicletaColor: esquemaColorBicicleta.optional(),
  bicicletaAro: esquemaAroBicicleta.optional(),
  bicicletaNumeroSerie: esquemaNumeroSerieBicicleta.optional(),
  bicicletaFotoUrl: esquemaFotoBicicleta.optional(),
  crearBicicletaNueva: Joi.boolean().default(false),
  bicicleteroId: Joi.string().uuid().optional(),
  tipo: Joi.string()
    .valid(...Object.values(TipoMovimiento))
    .required(),
  denegar: Joi.boolean().default(false),
  comentario: Joi.string().trim().max(600).allow('', null).optional(),
  motivo: Joi.when('denegar', {
    is: true,
    then: Joi.string().trim().min(3).max(600).required(),
    otherwise: Joi.string().trim().max(600).allow('', null)
  })
}).or('correo', 'rut');
