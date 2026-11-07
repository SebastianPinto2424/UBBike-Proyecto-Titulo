import bcrypt from 'bcrypt';
import { ErrorHttp } from '../../comun/errores/error-http';
import { crearEnlaceCorreo } from '../enlaces/enlace.servicio';
import { registrarAuditoria } from '../auditoria/auditoria.servicio';
import {
  crearCorreoCambioContrasena,
  crearCorreoContrasenaActualizada,
  crearCorreoCuentaActivada
} from '../correos/cuenta.plantillas';
import { enviarCorreo } from '../correos/correo.servicio';
import { crearNotificacion } from '../notificaciones/notificacion.servicio';
import { TipoNotificacion } from '../notificaciones/tipo-notificacion';
import {
  crearTokenSeguro,
  hashearToken,
  revocarTodosLosTokensRenovacion
} from './autenticacion.tokens';
import * as autenticacionRepositorio from './autenticacion.repositorio';
import { emitirCambioUsuarios } from '../usuarios/usuario.eventos';
import { cerrarSesionesTiempoReal } from '../../tiempo-real/tiempo-real';

export const solicitarCambioContrasena = async (correo: string) => {
  const usuario = await autenticacionRepositorio.buscarPorCorreo(correo.toLowerCase());

  if (!usuario) {
    return {
      message: 'Si el correo existe, enviaremos instrucciones de recuperación.'
    };
  }

  const tokenCambioContrasena = crearTokenSeguro();
  const usuarioActualizado = await autenticacionRepositorio.guardarTokenCambioContrasena(
    usuario.id,
    hashearToken(tokenCambioContrasena),
    new Date(Date.now() + 1000 * 60 * 30)
  );

  const enlace = crearEnlaceCorreo('cambiar-contrasena', tokenCambioContrasena);
  const correoCambio = crearCorreoCambioContrasena(usuarioActualizado.nombre, enlace);

  await enviarCorreo({
    para: usuarioActualizado.correo,
    asunto: correoCambio.asunto,
    texto: correoCambio.texto,
    html: correoCambio.html
  });

  await crearNotificacion({
    usuarioId: usuarioActualizado.id,
    titulo: 'Revisa tu correo',
    mensaje: 'Te enviamos un enlace seguro para cambiar tu contraseña.',
    tipo: TipoNotificacion.CUENTA
  });

  await registrarAuditoria({
    actorUsuarioId: usuarioActualizado.id,
    accion: 'CAMBIO_CONTRASENA_SOLICITADO',
    entidad: 'usuarios',
    entidadId: usuarioActualizado.id
  });

  return {
    message: 'Si el correo existe, enviaremos instrucciones de recuperación.'
  };
};

export const cambiarContrasena = async (token: string, contrasena: string) => {
  const usuario = await autenticacionRepositorio.buscarPorTokenCambioContrasena(
    hashearToken(token)
  );

  if (!usuario || !usuario.tokenCambioContrasenaExpiraEn) {
    throw new ErrorHttp(400, 'El enlace para cambiar tu contraseña no es válido');
  }

  if (usuario.tokenCambioContrasenaExpiraEn.getTime() < Date.now()) {
    throw new ErrorHttp(400, 'El enlace para cambiar tu contraseña expiró. Solicita uno nuevo.');
  }

  const esPrimeraActivacion = usuario.debeCambiarContrasena;

  await autenticacionRepositorio.actualizarContrasena(
    usuario.id,
    await bcrypt.hash(contrasena, 12)
  );
  await revocarTodosLosTokensRenovacion(usuario.id);
  cerrarSesionesTiempoReal(usuario.id, 'CONTRASENA_ACTUALIZADA');
  if (esPrimeraActivacion) {
    emitirCambioUsuarios();
  }

  await crearNotificacion({
    usuarioId: usuario.id,
    titulo: esPrimeraActivacion ? 'Cuenta activada' : 'Contraseña actualizada',
    mensaje: esPrimeraActivacion
      ? 'Ya puedes usar UBBike con tu nueva contraseña.'
      : 'Tu contraseña fue cambiada correctamente.',
    tipo: TipoNotificacion.CUENTA
  });

  const correoConfirmacion = esPrimeraActivacion
    ? crearCorreoCuentaActivada(usuario.nombre, usuario.rol)
    : crearCorreoContrasenaActualizada(usuario.nombre);
  await enviarCorreo({
    para: usuario.correo,
    asunto: correoConfirmacion.asunto,
    texto: correoConfirmacion.texto,
    html: correoConfirmacion.html
  });

  await registrarAuditoria({
    actorUsuarioId: usuario.id,
    accion: 'CONTRASENA_CAMBIADA',
    entidad: 'usuarios',
    entidadId: usuario.id
  });

  return {
    message: esPrimeraActivacion
      ? 'Cuenta activada correctamente. Ya puedes iniciar sesión.'
      : 'Contraseña actualizada correctamente',
    activacion: esPrimeraActivacion
  };
};

export const cambiarContrasenaSesion = async (
  usuarioId: string,
  contrasenaActual: string,
  contrasenaNueva: string
) => {
  const usuario = await autenticacionRepositorio.buscarPorId(usuarioId);

  if (!usuario) {
    throw new ErrorHttp(404, 'Usuario no encontrado');
  }

  const actualCoincide = await bcrypt.compare(contrasenaActual, usuario.contrasenaHash);
  if (!actualCoincide) {
    throw new ErrorHttp(400, 'La contraseña actual no es correcta');
  }

  const esIgualAnterior = await bcrypt.compare(contrasenaNueva, usuario.contrasenaHash);
  if (esIgualAnterior) {
    throw new ErrorHttp(400, 'La nueva contraseña debe ser distinta a la actual');
  }

  await autenticacionRepositorio.actualizar(usuario.id, {
    contrasenaHash: await bcrypt.hash(contrasenaNueva, 12),
    debeCambiarContrasena: false,
    versionSesion: {
      increment: 1
    }
  });

  await revocarTodosLosTokensRenovacion(usuario.id);
  if (usuario.debeCambiarContrasena) {
    emitirCambioUsuarios();
  }

  await crearNotificacion({
    usuarioId: usuario.id,
    titulo: 'Contraseña actualizada',
    mensaje: 'Tu contraseña fue cambiada correctamente. Vuelve a iniciar sesión.',
    tipo: TipoNotificacion.CUENTA
  });

  const correoContrasenaActualizada = crearCorreoContrasenaActualizada(usuario.nombre);
  await enviarCorreo({
    para: usuario.correo,
    asunto: correoContrasenaActualizada.asunto,
    texto: correoContrasenaActualizada.texto,
    html: correoContrasenaActualizada.html
  });

  await registrarAuditoria({
    actorUsuarioId: usuario.id,
    accion: 'CONTRASENA_CAMBIADA_SESION',
    entidad: 'usuarios',
    entidadId: usuario.id
  });

  return {
    message: 'Contraseña actualizada correctamente. Vuelve a iniciar sesión.'
  };
};
