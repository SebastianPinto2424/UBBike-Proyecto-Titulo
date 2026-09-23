import { SolicitudAutenticada } from '../../comun/middlewares/autenticacion.middleware';
import { controladorAsync } from '../../comun/utils/controlador-async';
import {
  cambiarContrasena as cambiarContrasenaServicio,
  cambiarContrasenaSesion as cambiarContrasenaSesionServicio,
  cerrarSesion as cerrarSesionServicio,
  completarRegistro as completarRegistroServicio,
  iniciarSesion as iniciarSesionServicio,
  obtenerUsuarioActual,
  refrescarToken as refrescarTokenServicio,
  registrarUsuario,
  solicitarCambioContrasena as solicitarCambioContrasenaServicio,
  verificarCorreo as verificarCorreoServicio
} from './autenticacion.servicio';

export const registrar = controladorAsync(async (req, res) => {
  const resultado = await registrarUsuario(req.body);
  return res.status(201).json(resultado);
});

export const iniciarSesion = controladorAsync(async (req, res) => {
  const resultado = await iniciarSesionServicio(req.body);
  return res.status(200).json(resultado);
});

export const obtenerPerfil = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const usuario = await obtenerUsuarioActual(req.usuario!.usuarioId);
  return res.status(200).json({ usuario });
});

export const verificarCorreo = controladorAsync(async (req, res) => {
  const token = String(req.body?.token ?? req.query.token ?? '');
  const resultado = await verificarCorreoServicio(token);
  return res.status(200).json(resultado);
});

export const completarRegistro = controladorAsync(async (req, res) => {
  const resultado = await completarRegistroServicio({
    token: req.body.token,
    nombre: req.body.nombre,
    contrasena: req.body.contrasena
  });
  return res.status(200).json(resultado);
});

export const solicitarCambioContrasena = controladorAsync(async (req, res) => {
  const resultado = await solicitarCambioContrasenaServicio(req.body.correo);
  return res.status(200).json(resultado);
});

export const cambiarContrasena = controladorAsync(async (req, res) => {
  const resultado = await cambiarContrasenaServicio(req.body.token, req.body.contrasena);
  return res.status(200).json(resultado);
});

export const cambiarContrasenaSesion = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const resultado = await cambiarContrasenaSesionServicio(
    req.usuario!.usuarioId,
    req.body.contrasenaActual,
    req.body.contrasenaNueva
  );
  return res.status(200).json(resultado);
});

export const refrescarToken = controladorAsync(async (req, res) => {
  const { usuarioId, refreshToken } = req.body;
  const resultado = await refrescarTokenServicio(usuarioId, refreshToken);
  return res.status(200).json(resultado);
});

export const cerrarSesion = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const resultado = await cerrarSesionServicio(req.usuario!.usuarioId, req.body?.refreshToken);
  return res.status(200).json(resultado);
});
