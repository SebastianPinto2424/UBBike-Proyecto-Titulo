import { SolicitudAutenticada } from '../../../comun/middlewares/autenticacion.middleware';
import { controladorAsync } from '../../../comun/utilidades/controlador-async';
import {
  liberarBicicleteroGuardia,
  listarGuardiasHabilitados,
  obtenerAsignacionActivaGuardia,
  seleccionarBicicleteroGuardia
} from './asignacion-guardia.servicio';

export const listarGuardias = controladorAsync<SolicitudAutenticada>(async (_req, res) => {
  const guardias = await listarGuardiasHabilitados();
  return res.status(200).json({ guardias });
});

export const obtenerMiBicicletero = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const asignacion = await obtenerAsignacionActivaGuardia(req.usuario!.usuarioId);
  return res.status(200).json({
    asignacion,
    bicicletero: asignacion?.bicicletero ?? null
  });
});

export const seleccionarMiBicicletero = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const asignacion = await seleccionarBicicleteroGuardia(
    req.usuario!.usuarioId,
    req.body.bicicleteroId
  );

  return res.status(200).json({
    asignacion,
    bicicletero: asignacion.bicicletero
  });
});

export const liberarMiBicicletero = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const resultado = await liberarBicicleteroGuardia(req.usuario!.usuarioId);
  return res.status(200).json(resultado);
});
