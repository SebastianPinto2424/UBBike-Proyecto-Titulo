import { SolicitudAutenticada } from '../../../comun/middlewares/autenticacion.middleware';
import { controladorAsync } from '../../../comun/utilidades/controlador-async';
import { buscarCoincidenciaGestionManual, registrarGestionManual } from './gestion-manual.servicio';
import { confirmarQr, denegarQr } from './acceso.servicio';

export const confirmarAccesoQr = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const movimiento = await confirmarQr({
    token: req.body.token,
    bicicleteroId: req.body.bicicleteroId,
    comentario: req.body.comentario,
    guardiaId: req.usuario!.usuarioId,
    rol: req.usuario!.rol
  });

  return res.status(201).json({ movimiento });
});

export const denegarAccesoQr = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const movimiento = await denegarQr({
    token: req.body.token,
    motivo: req.body.motivo,
    bicicleteroId: req.body.bicicleteroId,
    guardiaId: req.usuario!.usuarioId,
    rol: req.usuario!.rol
  });

  return res.status(201).json({ movimiento });
});

export const registrarManual = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const movimiento = await registrarGestionManual({
    guardiaId: req.usuario!.usuarioId,
    rol: req.usuario!.rol,
    nombre: req.body.nombre,
    correo: req.body.correo,
    rut: req.body.rut,
    bicicletaId: req.body.bicicletaId,
    bicicletaDescripcion: req.body.bicicletaDescripcion,
    bicicletaMarca: req.body.bicicletaMarca,
    bicicletaModelo: req.body.bicicletaModelo,
    bicicletaColor: req.body.bicicletaColor,
    bicicletaAro: req.body.bicicletaAro,
    bicicletaNumeroSerie: req.body.bicicletaNumeroSerie,
    bicicletaFotoUrl: req.body.bicicletaFotoUrl,
    crearBicicletaNueva: req.body.crearBicicletaNueva,
    bicicleteroId: req.body.bicicleteroId,
    tipo: req.body.tipo,
    denegar: req.body.denegar,
    motivo: req.body.motivo,
    comentario: req.body.comentario
  });

  return res.status(201).json({ movimiento });
});

export const buscarManual = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const coincidencia = await buscarCoincidenciaGestionManual({
    guardiaId: req.usuario!.usuarioId,
    correo: req.query.correo?.toString(),
    rut: req.query.rut?.toString()
  });

  return res.json({ coincidencia });
});
