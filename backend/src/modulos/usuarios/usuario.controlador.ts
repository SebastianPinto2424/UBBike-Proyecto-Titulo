import { controladorAsync } from '../../comun/utilidades/controlador-async';
import { actualizarPermisosUsuario } from './permisos.servicio';
import { crearUsuarioAdmin, eliminarUsuarioAdmin, listarUsuarios } from './usuario.servicio';
import { reenviarCorreoAccesoAdmin, reenviarVerificacionCorreoAdmin } from './invitacion.servicio';
import { RolUsuario } from './rol-usuario';

const leerBooleano = (valor: unknown) => (typeof valor === 'boolean' ? valor : undefined);

export const listar = controladorAsync(async (req, res) => {
  const usuarios = await listarUsuarios({
    q: typeof req.query.q === 'string' ? req.query.q : undefined,
    rol: req.query.rol as RolUsuario | undefined,
    cuentaActiva: leerBooleano(req.query.cuentaActiva),
    correoVerificado: leerBooleano(req.query.correoVerificado)
  });
  return res.status(200).json({ usuarios });
});

export const crear = controladorAsync(async (req, res) => {
  const usuario = await crearUsuarioAdmin(req.body, req.usuario?.usuarioId);
  return res.status(201).json({ usuario });
});

export const actualizarPermisos = controladorAsync(async (req, res) => {
  const usuario = await actualizarPermisosUsuario(req.params.id, req.body, req.usuario?.usuarioId);
  return res.status(200).json({ usuario });
});

export const reenviarVerificacion = controladorAsync(async (req, res) => {
  const resultado = await reenviarVerificacionCorreoAdmin(req.params.id, req.usuario?.usuarioId);
  return res.status(200).json(resultado);
});

export const reenviarAcceso = controladorAsync(async (req, res) => {
  const resultado = await reenviarCorreoAccesoAdmin(req.params.id, req.usuario?.usuarioId);
  return res.status(200).json(resultado);
});

export const eliminar = controladorAsync(async (req, res) => {
  const resultado = await eliminarUsuarioAdmin(req.params.id, req.usuario?.usuarioId);
  return res.status(200).json(resultado);
});
