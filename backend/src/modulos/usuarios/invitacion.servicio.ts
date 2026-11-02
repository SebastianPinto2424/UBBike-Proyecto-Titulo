import { ErrorHttp } from '../../comun/errores/error-http';
import { crearEnlaceCorreo } from '../enlaces/enlace.servicio';
import * as usuarioRepositorio from './usuario.repositorio';
import { registrarAuditoria } from '../auditoria/auditoria.servicio';
import {
  crearCorreoCuentaAdministrativa,
  crearCorreoVerificacion
} from '../correos/cuenta.plantillas';
import { enviarCorreo } from '../correos/correo.servicio';
import {
  crearTokenSeguro,
  hashearToken,
  horasExpiracionVerificacionCorreo
} from '../autenticacion/autenticacion.tokens';

export const crearDatosInvitacionAcceso = () => {
  const tokenCambioContrasena = crearTokenSeguro();
  const tokenCambioContrasenaHash = hashearToken(tokenCambioContrasena);
  const tokenCambioContrasenaExpiraEn = new Date(
    Date.now() + 1000 * 60 * 60 * horasExpiracionVerificacionCorreo
  );
  const enlaceDefinirContrasena = crearEnlaceCorreo('cambiar-contrasena', tokenCambioContrasena);

  return {
    tokenCambioContrasenaHash,
    tokenCambioContrasenaExpiraEn,
    enlaceDefinirContrasena
  };
};

export const reenviarVerificacionCorreoAdmin = async (
  usuarioId: string,
  actorUsuarioId?: string
) => {
  const usuario = await usuarioRepositorio.buscarPorId(usuarioId);

  if (!usuario) {
    throw new ErrorHttp(404, 'Usuario no encontrado');
  }
  if (usuario.eliminadoEn) {
    throw new ErrorHttp(409, 'No puedes reenviar la verificación a una cuenta eliminada');
  }
  if (usuario.correoVerificado) {
    throw new ErrorHttp(409, 'El correo ya está verificado');
  }
  if (usuario.debeCambiarContrasena) {
    throw new ErrorHttp(409, 'Esta cuenta aún no crea su contraseña; reenvía el correo de acceso');
  }

  const tokenVerificacion = crearTokenSeguro();
  const tokenVerificacionCorreo = hashearToken(tokenVerificacion);
  const tokenVerificacionCorreoExpiraEn = new Date(
    Date.now() + 1000 * 60 * 60 * horasExpiracionVerificacionCorreo
  );

  const usuarioActualizado = await usuarioRepositorio.actualizar(usuario.id, {
    tokenVerificacionCorreo,
    tokenVerificacionCorreoExpiraEn
  });

  const enlace = crearEnlaceCorreo('verificar-correo', tokenVerificacion);
  const correo = crearCorreoVerificacion(
    usuarioActualizado.nombre,
    usuarioActualizado.correo,
    enlace,
    tokenVerificacionCorreoExpiraEn
  );
  await enviarCorreo({
    para: usuarioActualizado.correo,
    asunto: correo.asunto,
    texto: correo.texto,
    html: correo.html
  });

  await registrarAuditoria({
    actorUsuarioId: actorUsuarioId ?? null,
    accion: 'CORREO_VERIFICACION_REENVIADO_ADMIN',
    entidad: 'usuarios',
    entidadId: usuarioActualizado.id,
    datos: {
      correo: usuarioActualizado.correo
    }
  });

  return { message: 'Correo de verificación reenviado' };
};

export const reenviarCorreoAccesoAdmin = async (usuarioId: string, actorUsuarioId?: string) => {
  const usuario = await usuarioRepositorio.buscarPorId(usuarioId);

  if (!usuario) {
    throw new ErrorHttp(404, 'Usuario no encontrado');
  }
  if (usuario.eliminadoEn) {
    throw new ErrorHttp(409, 'No puedes reenviar acceso a una cuenta eliminada');
  }
  if (!usuario.cuentaActiva) {
    throw new ErrorHttp(409, 'Reactiva el acceso antes de reenviar el correo');
  }
  if (!usuario.debeCambiarContrasena) {
    throw new ErrorHttp(409, 'La cuenta ya tiene su contraseña configurada');
  }

  const { tokenCambioContrasenaHash, tokenCambioContrasenaExpiraEn, enlaceDefinirContrasena } =
    crearDatosInvitacionAcceso();

  const usuarioActualizado = await usuarioRepositorio.actualizar(usuario.id, {
    tokenCambioContrasena: tokenCambioContrasenaHash,
    tokenCambioContrasenaExpiraEn
  });

  const correoInvitacion = crearCorreoCuentaAdministrativa(
    usuarioActualizado.nombre,
    enlaceDefinirContrasena,
    horasExpiracionVerificacionCorreo,
    usuarioActualizado.rol
  );
  await enviarCorreo({
    para: usuarioActualizado.correo,
    asunto: correoInvitacion.asunto,
    texto: correoInvitacion.texto,
    html: correoInvitacion.html
  });

  await registrarAuditoria({
    actorUsuarioId: actorUsuarioId ?? null,
    accion: 'CORREO_ACCESO_REENVIADO_ADMIN',
    entidad: 'usuarios',
    entidadId: usuarioActualizado.id,
    datos: {
      correo: usuarioActualizado.correo,
      rol: usuarioActualizado.rol
    }
  });

  return { message: 'Correo de acceso reenviado' };
};
