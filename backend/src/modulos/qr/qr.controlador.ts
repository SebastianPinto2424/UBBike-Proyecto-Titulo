import { SolicitudAutenticada } from '../../comun/middlewares/autenticacion.middleware';
import { controladorAsync } from '../../comun/utilidades/controlador-async';
import {
  consultarEstadoQr,
  generarQrTemporal,
  liberarQrTemporal,
  validarQrTemporal
} from './qr.servicio';

export const generar = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const qr = await generarQrTemporal({
    usuarioId: req.usuario!.usuarioId,
    bicicletaId: req.body.bicicletaId,
    bicicleteroId: req.body.bicicleteroId,
    tipo: req.body.tipo
  });

  return res.status(201).json({ qr });
});

export const validar = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const qr = await validarQrTemporal(req.body.token, {
    validadorUsuarioId: req.usuario!.usuarioId,
    rol: req.usuario!.rol
  });
  return res.status(200).json({ qr });
});

export const liberar = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  await liberarQrTemporal(req.body.token, {
    validadorUsuarioId: req.usuario!.usuarioId,
    rol: req.usuario!.rol
  });
  return res.status(204).send();
});

export const consultarEstado = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const estado = await consultarEstadoQr(String(req.params.id), req.usuario!.usuarioId);
  return res.status(200).json({ qr: estado });
});
