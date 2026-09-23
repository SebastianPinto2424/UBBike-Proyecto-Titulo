import { controladorAsync } from '../../comun/utils/controlador-async';
import {
  actualizarBicicletero,
  crearBicicletero,
  eliminarBicicletero,
  listarBicicleteros
} from './bicicletero.servicio';

export const listar = controladorAsync(async (_req, res) => {
  const bicicleteros = await listarBicicleteros();
  return res.status(200).json({ bicicleteros });
});

export const crear = controladorAsync(async (req, res) => {
  const bicicletero = await crearBicicletero({
    nombre: req.body.nombre,
    ubicacion: req.body.ubicacion,
    capacidad: req.body.capacidad,
    latitud: req.body.latitud,
    longitud: req.body.longitud
  });

  return res.status(201).json({ bicicletero });
});

export const actualizar = controladorAsync(async (req, res) => {
  const bicicletero = await actualizarBicicletero(req.params.id, {
    nombre: req.body.nombre,
    ubicacion: req.body.ubicacion,
    capacidad: req.body.capacidad,
    latitud: req.body.latitud,
    longitud: req.body.longitud
  });

  return res.status(200).json({ bicicletero });
});

export const eliminar = controladorAsync(async (req, res) => {
  const resultado = await eliminarBicicletero(req.params.id);
  return res.status(200).json(resultado);
});
