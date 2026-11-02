import { Router } from 'express';
import { middlewareAutenticacionSinExigirCambio } from '../../comun/middlewares/autenticacion.middleware';
import {
  ajustarMaximo,
  limitarIntentos
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
  esquemaRefreshToken,
  esquemaReenviarVerificacion,
  esquemaRegistro,
  esquemaSolicitudCambioContrasena,
  esquemaVerificarCorreo
} from './autenticacion.validacion';

const rutasAutenticacion = Router();

rutasAutenticacion.post(
  ['/registro', '/register'],
  limitarIntentos({
    ventanaMs: 15 * 60 * 1000,
    maximo: ajustarMaximo(20),
    mensaje: 'Demasiados registros desde este origen. Intenta más tarde.'
  }),
  validarCuerpo(esquemaRegistro),
  registrar
);

rutasAutenticacion.post(
  '/login',
  limitarIntentos({
    ventanaMs: 15 * 60 * 1000,
    maximo: ajustarMaximo(10),
    mensaje: 'Demasiados intentos fallidos para esta cuenta. Intenta más tarde.',
    contarSoloFallos: true,
    clave: (req) =>
      `login:${String(req.body?.correo ?? '')
        .trim()
        .toLowerCase()}`
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
  limitarIntentos({
    ventanaMs: 15 * 60 * 1000,
    maximo: ajustarMaximo(5),
    mensaje: 'Demasiadas solicitudes de reenvío. Intenta más tarde.'
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
  limitarIntentos({
    ventanaMs: 15 * 60 * 1000,
    maximo: ajustarMaximo(5),
    mensaje: 'Demasiadas solicitudes de cambio de contraseña. Intenta más tarde.'
  }),
  validarCuerpo(esquemaSolicitudCambioContrasena),
  solicitarCambioContrasena
);

rutasAutenticacion.post(
  '/cambiar-contrasena',
  limitarIntentos({
    ventanaMs: 15 * 60 * 1000,
    maximo: ajustarMaximo(10),
    mensaje: 'Demasiados intentos de cambio de contraseña. Intenta más tarde.',
    contarSoloFallos: true
  }),
  validarCuerpo(esquemaCambioContrasena),
  cambiarContrasena
);

rutasAutenticacion.post(
  '/refresh',
  limitarIntentos({
    ventanaMs: 15 * 60 * 1000,
    maximo: ajustarMaximo(30),
    mensaje: 'Demasiadas solicitudes de refresh. Intenta más tarde.',

    contarSoloFallos: true
  }),
  validarCuerpo(esquemaRefreshToken),
  refrescarToken
);

rutasAutenticacion.post(
  '/cambiar-contrasena-sesion',
  middlewareAutenticacionSinExigirCambio,
  limitarIntentos({
    ventanaMs: 15 * 60 * 1000,
    maximo: ajustarMaximo(10),
    mensaje: 'Demasiados intentos de cambio de contraseña. Intenta más tarde.',
    contarSoloFallos: true
  }),
  validarCuerpo(esquemaCambioContrasenaSesion),
  cambiarContrasenaSesion
);

rutasAutenticacion.post('/logout', middlewareAutenticacionSinExigirCambio, cerrarSesion);

export { rutasAutenticacion };
