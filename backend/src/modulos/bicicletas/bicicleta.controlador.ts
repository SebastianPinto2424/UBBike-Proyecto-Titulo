import { SolicitudAutenticada } from '../../comun/middlewares/autenticacion.middleware';
import { controladorAsync } from '../../comun/utilidades/controlador-async';
import {
  activarBicicleta,
  actualizarBicicleta,
  crearBicicleta,
  desactivarBicicleta,
  eliminarBicicleta,
  listarBicicletasUsuario,
  obtenerBicicletaActivaUsuario
} from './bicicleta.servicio';

export const listar = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const bicicletas = await listarBicicletasUsuario(req.usuario!.usuarioId);
  return res.status(200).json({ bicicletas });
});

export const obtenerActiva = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const bicicleta = await obtenerBicicletaActivaUsuario(req.usuario!.usuarioId);
  return res.status(200).json({ bicicleta });
});

export const crear = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const bicicleta = await crearBicicleta({
    usuarioId: req.usuario!.usuarioId,
    descripcion: req.body.descripcion,
    marca: req.body.marca,
    modelo: req.body.modelo,
    color: req.body.color,
    aro: req.body.aro,
    numeroSerie: req.body.numeroSerie,
    fotoUrl: req.body.fotoUrl,
    activar: req.body.activar
  });

  return res.status(201).json({ bicicleta });
});

export const actualizar = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const bicicleta = await actualizarBicicleta(req.usuario!.usuarioId, req.params.id, req.body);
  return res.status(200).json({ bicicleta });
});

export const eliminar = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const resultado = await eliminarBicicleta(req.usuario!.usuarioId, req.params.id);
  return res.status(200).json(resultado);
});

export const activar = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const bicicleta = await activarBicicleta(req.usuario!.usuarioId, req.params.id);
  return res.status(200).json({ bicicleta });
});

export const desactivar = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const bicicleta = await desactivarBicicleta(req.usuario!.usuarioId, req.params.id);
  return res.status(200).json({ bicicleta });
});
