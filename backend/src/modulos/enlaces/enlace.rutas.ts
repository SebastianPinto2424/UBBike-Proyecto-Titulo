import express, { Router } from 'express';
import {
  ajustarMaximo,
  limitarIntentos,
  porHuellaDelCampo,
  quinceMinutos
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
const limitarRed = limitarIntentos({
  ventanaMs: quinceMinutos,
  maximo: ajustarMaximo(300),
  mensaje: 'Hay demasiados intentos desde esta red. Espera unos minutos y vuelve a intentarlo.',
  alBloquear: responderBloqueoEnlace
});
const limitarFormulario = limitarIntentos({
  ventanaMs: quinceMinutos,
  maximo: ajustarMaximo(10),
  mensaje:
    'Hiciste demasiados intentos con este enlace. Espera unos minutos y vuelve a intentarlo.',
  alBloquear: responderBloqueoEnlace,
  clave: porHuellaDelCampo('enlace', 'token')
});

rutasEnlaces.post(
  '/reenviar-verificacion',
  leerFormulario,
  limitarRed,
  limitarFormulario,
  reenviarEnlace
);
rutasEnlaces.post('/:accion', leerFormulario, limitarRed, limitarFormulario, procesarFormulario);

export { rutasEnlaces };
