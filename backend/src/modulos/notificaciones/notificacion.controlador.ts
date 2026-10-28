import { SolicitudAutenticada } from '../../comun/middlewares/autenticacion.middleware';
import { controladorAsync } from '../../comun/utilidades/controlador-async';
import {
  eliminarDispositivo as eliminarDispositivoServicio,
  listarNotificacionesUsuario,
  marcarNotificacionLeida,
  marcarTodasLeidas,
  registrarDispositivo as registrarDispositivoServicio
} from './notificacion.servicio';

export const listarNotificaciones = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const cursor = typeof req.query.cursor === 'string' ? req.query.cursor : undefined;
  const limite = req.query.limite ? Number(req.query.limite) : undefined;
  const soloNoLeidas = Boolean(req.query.soloNoLeidas);

  const resultado = await listarNotificacionesUsuario(req.usuario!.usuarioId, {
    cursor,
    limite,
    soloNoLeidas
  });

  return res.status(200).json(resultado);
});

export const marcarLeida = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const notificacion = await marcarNotificacionLeida(req.usuario!.usuarioId, req.params.id);
  return res.status(200).json({ notificacion });
});

export const marcarTodas = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const resultado = await marcarTodasLeidas(req.usuario!.usuarioId);
  return res.status(200).json(resultado);
});

export const registrarDispositivo = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  await registrarDispositivoServicio(req.usuario!.usuarioId, req.body.token, req.body.plataforma);
  return res.status(201).json({ message: 'Dispositivo registrado para notificaciones' });
});

export const eliminarDispositivo = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  await eliminarDispositivoServicio(req.usuario!.usuarioId, req.body.token);
  return res.status(200).json({ message: 'Dispositivo eliminado' });
});
