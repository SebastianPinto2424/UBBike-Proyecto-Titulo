import express, { Router } from 'express';
import {
  ajustarMaximo,
  limitarIntentos
} from '../../comun/middlewares/limitador-intentos.middleware';
import {
  mostrarFormulario,
  mostrarResultado,
  prepararRespuestaEnlace,
  procesarFormulario,
  reenviarEnlace,
  responderBloqueoEnlace
} from './enlace.controlador';
import { carpetaRecursos } from './enlace.recursos';

const rutasEnlaces = Router();

rutasEnlaces.use(
  '/recursos',
  express.static(carpetaRecursos, {
    index: false,
    fallthrough: false,
    maxAge: '7d'
  })
);
rutasEnlaces.use(prepararRespuestaEnlace);
rutasEnlaces.get('/resultado/:resultado', mostrarResultado);
rutasEnlaces.get('/:accion', mostrarFormulario);

const leerFormulario = express.urlencoded({ extended: false, limit: '8kb' });
const limitarFormulario = limitarIntentos({
  ventanaMs: 15 * 60 * 1000,
  maximo: ajustarMaximo(10),
  mensaje:
    'Hiciste demasiados intentos con este enlace. Espera unos minutos y vuelve a intentarlo.',
  alBloquear: responderBloqueoEnlace
});

rutasEnlaces.post('/reenviar-verificacion', leerFormulario, limitarFormulario, reenviarEnlace);
rutasEnlaces.post('/:accion', leerFormulario, limitarFormulario, procesarFormulario);

export { rutasEnlaces };
