import type { SolicitudAutenticada } from '../../comun/middlewares/autenticacion.middleware';
import { controladorAsync } from '../../comun/utilidades/controlador-async';
import {
  asignarGuardiaABicicletero,
  liberarGuardiaDeBicicletero
} from '../acceso/asignaciones/asignacion-guardia.servicio';
import {
  actualizarBicicletero,
  crearBicicletero,
  eliminarBicicletero,
  listarBicicleteros
} from './bicicletero.servicio';

export const listar = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const bicicleteros = await listarBicicleteros(req.usuario?.rol);
  return res.status(200).json({ bicicleteros });
});

export const liberarGuardia = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const resultado = await liberarGuardiaDeBicicletero(req.params.id, req.usuario!.usuarioId);
  return res.status(200).json(resultado);
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

export const asignarGuardia = controladorAsync<SolicitudAutenticada>(async (req, res) => {
  const asignacion = await asignarGuardiaABicicletero(
    req.params.id,
    req.body.guardiaId,
    req.usuario!.usuarioId
  );
  return res.status(200).json({ asignacion });
});
