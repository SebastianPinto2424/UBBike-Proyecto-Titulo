import { Router } from 'express';
import { middlewareAutenticacionSinExigirCambio } from '../../comun/middlewares/autenticacion.middleware';
import {
  ajustarMaximo,
  limitarIntentos,
  porCampoDelCuerpo,
  porHuellaDelCampo,
  porUsuarioAutenticado,
  quinceMinutos
} from '../../comun/middlewares/limitador-intentos.middleware';
import { validarCuerpo } from '../../comun/middlewares/validacion.middleware';
import {
  cambiarContrasena,
  cambiarContrasenaSesion,
  cerrarSesion,
  completarRegistro,
  iniciarSesion,
  obtenerPerfil,
  refrescarToken,
  reenviarVerificacion,
  registrar,
  solicitarCambioContrasena,
  verificarCorreo
} from './autenticacion.controlador';
import {
  esquemaCambioContrasena,
  esquemaCambioContrasenaSesion,
  esquemaCompletarRegistro,
  esquemaInicioSesion,
  esquemaTokenRenovacion,
  esquemaReenviarVerificacion,
  esquemaRegistro,
  esquemaSolicitudCambioContrasena,
  esquemaVerificarCorreo
} from './autenticacion.validacion';

const rutasAutenticacion = Router();

const limitarRed = (maximo: number, mensaje: string) =>
  limitarIntentos({ ventanaMs: quinceMinutos, maximo: ajustarMaximo(maximo), mensaje });

rutasAutenticacion.post(
  ['/registro', '/register'],
  limitarRed(300, 'Demasiados registros desde esta red. Intenta más tarde.'),
  limitarIntentos({
    ventanaMs: quinceMinutos,
    maximo: ajustarMaximo(10),
    mensaje: 'Demasiados intentos de registro con este correo. Intenta más tarde.',
    clave: porCampoDelCuerpo('registro', 'correo')
  }),
  validarCuerpo(esquemaRegistro),
  registrar
);

rutasAutenticacion.post(
  '/login',
  limitarIntentos({
    ventanaMs: quinceMinutos,
    maximo: ajustarMaximo(10),
    mensaje: 'Demasiados intentos fallidos para esta cuenta. Intenta más tarde.',
    contarSoloFallos: true,
    clave: porCampoDelCuerpo('login', 'correo')
  }),
  validarCuerpo(esquemaInicioSesion),
  iniciarSesion
);

rutasAutenticacion.get(
  ['/perfil', '/me', '/yo'],
  middlewareAutenticacionSinExigirCambio,
  obtenerPerfil
);

rutasAutenticacion.get('/verificar-correo', verificarCorreo);
rutasAutenticacion.post(
  '/verificar-correo',
  validarCuerpo(esquemaVerificarCorreo),
  verificarCorreo
);

rutasAutenticacion.post(
  '/reenviar-verificacion',
  limitarRed(100, 'Demasiadas solicitudes de reenvío desde esta red. Intenta más tarde.'),
  limitarIntentos({
    ventanaMs: quinceMinutos,
    maximo: ajustarMaximo(5),
    mensaje: 'Demasiadas solicitudes de reenvío. Intenta más tarde.',
    clave: porCampoDelCuerpo('reenvio', 'correo')
  }),
  validarCuerpo(esquemaReenviarVerificacion),
  reenviarVerificacion
);

rutasAutenticacion.post(
  '/completar-registro',
  validarCuerpo(esquemaCompletarRegistro),
  completarRegistro
);

rutasAutenticacion.post(
  '/solicitar-cambio-contrasena',
  limitarRed(
    100,
    'Demasiadas solicitudes de cambio de contraseña desde esta red. Intenta más tarde.'
  ),
  limitarIntentos({
    ventanaMs: quinceMinutos,
    maximo: ajustarMaximo(5),
    mensaje: 'Demasiadas solicitudes de cambio de contraseña. Intenta más tarde.',
    clave: porCampoDelCuerpo('recuperacion', 'correo')
  }),
  validarCuerpo(esquemaSolicitudCambioContrasena),
  solicitarCambioContrasena
);

rutasAutenticacion.post(
  '/cambiar-contrasena',
  limitarIntentos({
    ventanaMs: quinceMinutos,
    maximo: ajustarMaximo(10),
    mensaje: 'Demasiados intentos de cambio de contraseña. Intenta más tarde.',
    contarSoloFallos: true,
    clave: porHuellaDelCampo('cambio', 'token')
  }),
  validarCuerpo(esquemaCambioContrasena),
  cambiarContrasena
);

rutasAutenticacion.post(
  '/refresh',
  limitarIntentos({
    ventanaMs: quinceMinutos,
    maximo: ajustarMaximo(30),
    mensaje: 'Demasiadas solicitudes de renovación de sesión. Intenta más tarde.',
    contarSoloFallos: true,
    clave: porCampoDelCuerpo('renovacion', 'usuarioId')
  }),
  validarCuerpo(esquemaTokenRenovacion),
  refrescarToken
);

rutasAutenticacion.post(
  '/cambiar-contrasena-sesion',
  middlewareAutenticacionSinExigirCambio,
  limitarIntentos({
    ventanaMs: quinceMinutos,
    maximo: ajustarMaximo(10),
    mensaje: 'Demasiados intentos de cambio de contraseña. Intenta más tarde.',
    contarSoloFallos: true,
    clave: porUsuarioAutenticado('cambio-sesion')
  }),
  validarCuerpo(esquemaCambioContrasenaSesion),
  cambiarContrasenaSesion
);

rutasAutenticacion.post('/logout', middlewareAutenticacionSinExigirCambio, cerrarSesion);

export { rutasAutenticacion };
