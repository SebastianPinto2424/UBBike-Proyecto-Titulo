import bcrypt from 'bcryptjs';
import { liberarBicicleteroGuardia } from '../acceso/asignaciones/asignacion-guardia.servicio';
import { ErrorHttp } from '../../comun/errores/error-http';
import { registrarAuditoria } from '../auditoria/auditoria.servicio';
import { olvidarDispositivosDeUsuario } from '../notificaciones/notificacion.servicio';
import { cerrarSesionesTiempoReal } from '../../tiempo-real/tiempo-real';
import { mapearUsuarioPublico } from '../usuarios/usuario.mapeador';
import { RolUsuario } from '../usuarios/rol-usuario';
import {
  crearRefreshToken,
  crearTokenSesion,
  guardarRefreshToken,
  revocarRefreshToken,
  revocarTodosLosRefreshTokens,
  rotarRefreshToken
} from './autenticacion.tokens';
import * as autenticacionRepositorio from './autenticacion.repositorio';

type DatosLogin = {
  correo: string;
  contrasena: string;
};

const cerrarOtrasSesiones = async (usuarioId: string) => {
  const actualizado = await autenticacionRepositorio.actualizar(usuarioId, {
    versionSesion: { increment: 1 }
  });
  await revocarTodosLosRefreshTokens(usuarioId);
  await olvidarDispositivosDeUsuario(usuarioId);
  cerrarSesionesTiempoReal(usuarioId);
  return actualizado.versionSesion;
};

export const iniciarSesion = async (datos: DatosLogin) => {
  const usuario = await autenticacionRepositorio.buscarPorCorreo(datos.correo.toLowerCase());

  if (!usuario) {
    await registrarAuditoria({
      accion: 'LOGIN_FALLIDO',
      entidad: 'usuarios',
      datos: {
        correo: datos.correo.toLowerCase(),
        motivo: 'usuario_no_encontrado'
      }
    });
    throw new ErrorHttp(401, 'Credenciales inválidas');
  }

  const bloquear = async (motivo: string, error: ErrorHttp) => {
    await registrarAuditoria({
      actorUsuarioId: usuario.id,
      accion: 'LOGIN_BLOQUEADO',
      entidad: 'usuarios',
      entidadId: usuario.id,
      datos: { motivo }
    });
    throw error;
  };

  if (usuario.registroParcial && usuario.cuentaActiva) {
    await bloquear(
      'registro_parcial',
      new ErrorHttp(403, 'Debes completar tu registro antes de iniciar sesión')
    );
  }

  const contrasenaCoincide = await bcrypt.compare(datos.contrasena, usuario.contrasenaHash);

  if (!contrasenaCoincide) {
    await registrarAuditoria({
      actorUsuarioId: usuario.id,
      accion: 'LOGIN_FALLIDO',
      entidad: 'usuarios',
      entidadId: usuario.id,
      datos: { motivo: 'contrasena_incorrecta' }
    });
    throw new ErrorHttp(401, 'Credenciales inválidas');
  }

  if (!usuario.cuentaActiva) {
    await bloquear('cuenta_desactivada', new ErrorHttp(403, 'La cuenta está desactivada'));
  }

  if (!usuario.correoVerificado) {
    await bloquear(
      'correo_no_verificado',
      new ErrorHttp(
        403,
        'Aún no confirmas tu correo. Abre el enlace que te enviamos o pide uno nuevo.',
        'CORREO_NO_VERIFICADO'
      )
    );
  }

  await registrarAuditoria({
    actorUsuarioId: usuario.id,
    accion: 'LOGIN_EXITOSO',
    entidad: 'usuarios',
    entidadId: usuario.id
  });

  const versionSesion = await cerrarOtrasSesiones(usuario.id);
  const token = crearTokenSesion(usuario.id, usuario.rol, versionSesion);
  const refreshToken = crearRefreshToken();
  await guardarRefreshToken(usuario.id, refreshToken, versionSesion);

  return {
    usuario: mapearUsuarioPublico(usuario),
    token,
    refreshToken
  };
};

export const obtenerUsuarioActual = async (usuarioId: string) => {
  const usuario = await autenticacionRepositorio.buscarPorId(usuarioId);

  if (!usuario) {
    throw new ErrorHttp(404, 'Usuario no encontrado');
  }

  return mapearUsuarioPublico(usuario);
};

export const refrescarToken = async (usuarioId: string, refreshTokenRecibido: string) => {
  const usuario = await autenticacionRepositorio.buscarPorId(usuarioId);

  if (!usuario || !usuario.cuentaActiva || !usuario.correoVerificado) {
    throw new ErrorHttp(401, 'Sesión inválida');
  }

  const nuevoRefreshToken = crearRefreshToken();
  const valido = await rotarRefreshToken(
    usuarioId,
    refreshTokenRecibido,
    nuevoRefreshToken,
    usuario.versionSesion
  );

  if (!valido) {
    throw new ErrorHttp(401, 'Refresh token inválido o expirado. Inicia sesión nuevamente.');
  }

  const nuevoToken = crearTokenSesion(usuario.id, usuario.rol, usuario.versionSesion);

  return {
    token: nuevoToken,
    refreshToken: nuevoRefreshToken
  };
};

export const cerrarSesion = async (
  usuarioId: string,
  refreshTokenRecibido?: string,
  rol?: string
) => {
  if (rol === RolUsuario.GUARDIA) {
    await liberarBicicleteroGuardia(usuarioId);
  }

  if (refreshTokenRecibido) {
    await revocarRefreshToken(usuarioId, refreshTokenRecibido);
  } else {
    await revocarTodosLosRefreshTokens(usuarioId);
  }

  await autenticacionRepositorio.actualizar(usuarioId, {
    versionSesion: { increment: 1 }
  });
  await olvidarDispositivosDeUsuario(usuarioId);

  await registrarAuditoria({
    actorUsuarioId: usuarioId,
    accion: 'LOGOUT',
    entidad: 'usuarios',
    entidadId: usuarioId
  });

  return { message: 'Sesión cerrada correctamente' };
};
