import bcrypt from 'bcrypt';
import { liberarBicicleteroGuardia } from '../acceso/asignaciones/asignacion-guardia.servicio';
import { ErrorHttp } from '../../comun/errores/error-http';
import { registrarAuditoria } from '../auditoria/auditoria.servicio';
import { olvidarDispositivosDeUsuario } from '../notificaciones/notificacion.servicio';
import { cerrarSesionesTiempoReal } from '../../tiempo-real/tiempo-real';
import { mapearUsuarioPublico } from '../usuarios/usuario.mapeador';
import { RolUsuario } from '../usuarios/rol-usuario';
import {
  crearTokenRenovacion,
  crearTokenSesion,
  guardarTokenRenovacion,
  revocarTokenRenovacion,
  revocarTodosLosTokensRenovacion,
  rotarTokenRenovacion
} from './autenticacion.tokens';
import * as autenticacionRepositorio from './autenticacion.repositorio';

type DatosInicioSesion = {
  correo: string;
  contrasena: string;
};

const hashComparacionSinUsuario = '$2a$12$dn6irJbqCmX5pOWiucMhW.zaebh1UejzRoC9yDxz5JRvPeLBfdaWO';

const errorCredencialesInvalidas = () =>
  new ErrorHttp(401, 'Credenciales inválidas', 'CREDENCIALES_INVALIDAS');

const cerrarOtrasSesiones = async (usuarioId: string) => {
  const actualizado = await autenticacionRepositorio.actualizar(usuarioId, {
    versionSesion: { increment: 1 }
  });
  await revocarTodosLosTokensRenovacion(usuarioId);
  await olvidarDispositivosDeUsuario(usuarioId);
  cerrarSesionesTiempoReal(usuarioId);
  return actualizado.versionSesion;
};

export const iniciarSesion = async (datos: DatosInicioSesion) => {
  const correo = datos.correo.toLowerCase();
  const usuario = await autenticacionRepositorio.buscarPorCorreo(correo);
  const contrasenaCoincide = await bcrypt.compare(
    datos.contrasena,
    usuario?.contrasenaHash ?? hashComparacionSinUsuario
  );

  if (!usuario || !contrasenaCoincide) {
    await registrarAuditoria(
      usuario
        ? {
            actorUsuarioId: usuario.id,
            accion: 'LOGIN_FALLIDO',
            entidad: 'usuarios',
            entidadId: usuario.id,
            datos: { motivo: 'contrasena_incorrecta' }
          }
        : {
            accion: 'LOGIN_FALLIDO',
            entidad: 'usuarios',
            datos: {
              correo,
              motivo: 'usuario_no_encontrado'
            }
          }
    );
    throw errorCredencialesInvalidas();
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
  const tokenRenovacion = crearTokenRenovacion();
  await guardarTokenRenovacion(usuario.id, tokenRenovacion, versionSesion);

  return {
    usuario: mapearUsuarioPublico(usuario),
    token,
    refreshToken: tokenRenovacion
  };
};

export const obtenerUsuarioActual = async (usuarioId: string) => {
  const usuario = await autenticacionRepositorio.buscarPorId(usuarioId);

  if (!usuario) {
    throw new ErrorHttp(404, 'Usuario no encontrado');
  }

  return mapearUsuarioPublico(usuario);
};

export const refrescarToken = async (usuarioId: string, tokenRenovacionRecibido: string) => {
  const usuario = await autenticacionRepositorio.buscarPorId(usuarioId);

  if (!usuario || !usuario.cuentaActiva || !usuario.correoVerificado) {
    throw new ErrorHttp(401, 'Sesión inválida');
  }

  const nuevoTokenRenovacion = crearTokenRenovacion();
  const valido = await rotarTokenRenovacion(
    usuarioId,
    tokenRenovacionRecibido,
    nuevoTokenRenovacion,
    usuario.versionSesion
  );

  if (!valido) {
    throw new ErrorHttp(401, 'Token de renovación inválido o expirado. Inicia sesión nuevamente.');
  }

  const nuevoToken = crearTokenSesion(usuario.id, usuario.rol, usuario.versionSesion);

  return {
    token: nuevoToken,
    refreshToken: nuevoTokenRenovacion
  };
};

export const cerrarSesion = async (
  usuarioId: string,
  tokenRenovacionRecibido?: string,
  rol?: string
) => {
  if (rol === RolUsuario.GUARDIA) {
    await liberarBicicleteroGuardia(usuarioId);
  }

  if (tokenRenovacionRecibido) {
    await revocarTokenRenovacion(usuarioId, tokenRenovacionRecibido);
  } else {
    await revocarTodosLosTokensRenovacion(usuarioId);
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
