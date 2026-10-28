import Joi from 'joi';
import { TipoMovimiento } from '../historial/tipo-movimiento';

export const esquemaTokenQr = Joi.string().trim().max(160).messages({
  'string.max': 'Este código no es un QR válido de UBBike'
});

export const esquemaGenerarQr = Joi.object({
  bicicletaId: Joi.string().uuid().optional(),
  bicicleteroId: Joi.string().uuid().optional(),
  tipo: Joi.string()
    .valid(...Object.values(TipoMovimiento))
    .optional()
});

export const esquemaValidarQr = Joi.object({
  token: esquemaTokenQr.required()
});
