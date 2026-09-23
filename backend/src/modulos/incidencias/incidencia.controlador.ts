import { SolicitudAutenticada } from '../../comun/middlewares/autenticacion.middleware';
import { controladorAsync } from '../../comun/utils/controlador-async';
import {
  actualizarEstadoIncidencia,
  crearIncidencia,
  listarIncidencias,
  recordarIncidencia
} from './incidencia.servicio';

export const crear = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const incidencia = await crearIncidencia({
    usuarioId: req.usuario!.usuarioId,
    rol: req.usuario!.rol,
    bicicleteroId: req.body.bicicleteroId,
    bicicletaId: req.body.bicicletaId,
    tipo: req.body.tipo,
    descripcion: req.body.descripcion,
    ip: req.ip,
    userAgent: req.get('user-agent')
  });

  return res.status(201).json({ incidencia });
});

export const listar = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const cursor = typeof req.query.cursor === 'string' ? req.query.cursor : undefined;
  const limite = req.query.limite ? Number(req.query.limite) : undefined;

  const resultado = await listarIncidencias({
    usuarioId: req.usuario!.usuarioId,
    rol: req.usuario!.rol,
    estado: req.query.estado as never,
    tipo: req.query.tipo as never,
    bicicleteroId: req.query.bicicleteroId as string | undefined,
    q: req.query.q as string | undefined,
    cursor,
    limite
  });

  return res.status(200).json(resultado);
});

export const actualizarEstado = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const incidencia = await actualizarEstadoIncidencia({
    usuarioId: req.usuario!.usuarioId,
    rol: req.usuario!.rol,
    incidenciaId: req.params.id,
    estado: req.body.estado,
    respuesta: req.body.respuesta,
    ip: req.ip,
    userAgent: req.get('user-agent')
  });

  return res.status(200).json({ incidencia });
});

export const recordar = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const incidencia = await recordarIncidencia({
    usuarioId: req.usuario!.usuarioId,
    rol: req.usuario!.rol,
    incidenciaId: req.params.id
  });

  return res.status(200).json({ incidencia });
});
