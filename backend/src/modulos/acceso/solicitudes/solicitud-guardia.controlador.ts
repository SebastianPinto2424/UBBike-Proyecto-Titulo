import { SolicitudAutenticada } from '../../../comun/middlewares/autenticacion.middleware';
import { controladorAsync } from '../../../comun/utils/controlador-async';
import {
  actualizarEstadoSolicitudGuardia,
  crearSolicitudGuardia,
  listarSolicitudesGuardia,
  notificarGuardiaSolicitud
} from './solicitud-guardia.servicio';
import { EstadoSolicitudGuardia } from './estado-solicitud-guardia';

export const crear = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const solicitud = await crearSolicitudGuardia({
    usuarioId: req.usuario!.usuarioId,
    bicicleteroId: req.body.bicicleteroId,
    tipo: req.body.tipo,
    mensaje: req.body.mensaje
  });

  return res.status(201).json({ solicitud });
});

export const listar = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const solicitudes = await listarSolicitudesGuardia({
    usuarioId: req.usuario!.usuarioId,
    rol: req.usuario!.rol,
    estado: req.query.estado?.toString() as EstadoSolicitudGuardia | 'TODOS' | undefined,
    q: req.query.q?.toString(),
    limite: req.query.limite ? Number(req.query.limite) : undefined
  });

  return res.status(200).json({ solicitudes });
});

export const actualizarEstado = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const solicitud = await actualizarEstadoSolicitudGuardia(
    req.usuario!.usuarioId,
    req.usuario!.rol,
    req.params.id,
    req.body.estado,
    req.body.nota
  );

  return res.status(200).json({ solicitud });
});

export const notificarGuardia = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const solicitud = await notificarGuardiaSolicitud({
    usuarioId: req.usuario!.usuarioId,
    rol: req.usuario!.rol,
    solicitudId: req.params.id,
    mensaje: req.body.mensaje
  });

  return res.status(200).json({ solicitud });
});
