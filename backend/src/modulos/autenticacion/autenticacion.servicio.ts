import bcrypt from 'bcryptjs';
import { ErrorHttp } from '../../comun/errors/error-http';
import { entorno } from '../../configuracion/entorno';
import { registrarAuditoria } from '../auditoria/auditoria.servicio';
import {
  crearCorreoCambioContrasena,
  crearCorreoContrasenaActualizada,
  crearCorreoCuentaActivada,
  crearCorreoCuentaVerificada,
  crearCorreoVerificacion,
  enviarCorreo
} from '../correos/correo.servicio';
import {
  crearNotificacion,
  notificarUsuariosPorRol
} from '../notificaciones/notificacion.servicio';
import { TipoNotificacion } from '../notificaciones/tipo-notificacion';
import { mapearUsuarioPublico } from '../usuarios/usuario.mapeador';
import { RolUsuario } from '../usuarios/rol-usuario';
import {
  crearRefreshToken,
  crearTokenSeguro,
  crearTokenSesion,
  guardarRefreshToken,
  hashearToken,
  horasExpiracionVerificacionCorreo,
  resolverRolRegistrable,
  revocarRefreshToken,
  revocarTodosLosRefreshTokens,
  rotarRefreshToken
} from './autenticacion.tokens';
import * as autenticacionRepositorio from './autenticacion.repositorio';

type DatosRegistro = {
  nombre: string;
  rut?: string;
  correo: string;
  contrasena: string;
};

type DatosLogin = {
  correo: string;
  contrasena: string;
};

type DatosCompletarRegistro = {
  token: string;
  nombre: string;
  contrasena: string;
};

const archivarCorreoEliminado = (correo: string, usuarioId: string) => {
  const sufijo = `.eliminado.${usuarioId.slice(0, 8)}`;
  const disponible = 160 - sufijo.length;

  return `${correo.slice(0, disponible)}${sufijo}`;
};

export const registrarUsuario = async (datos: DatosRegistro) => {
  const correoNormalizado = datos.correo.trim().toLowerCase();
  const rut = datos.rut?.trim() || null;
  const rolAsignado = resolverRolRegistrable(correoNormalizado);
  const usuarioPorCorreo = await autenticacionRepositorio.buscarPorCorreo(correoNormalizado);
  const usuarioPorRut = rut ? await autenticacionRepositorio.buscarPorRut(rut) : null;

  if (usuarioPorCorreo && !usuarioPorCorreo.eliminadoEn) {
    throw new ErrorHttp(409, 'El correo ya está registrado');
  }

  if (usuarioPorRut && !usuarioPorRut.eliminadoEn) {
    throw new ErrorHttp(409, 'El RUT ya está registrado');
  }

  const contrasenaHash = await bcrypt.hash(datos.contrasena, 12);
  const tokenVerificacion = crearTokenSeguro();
  const tokenVerificacionCorreo = hashearToken(tokenVerificacion);
  const tokenVerificacionCorreoExpiraEn = new Date(
    Date.now() + 1000 * 60 * 60 * horasExpiracionVerificacionCorreo
  );
  const cuentasEliminadasALiberar = [usuarioPorCorreo, usuarioPorRut].filter(
    (cuenta, indice, lista) =>
      cuenta?.eliminadoEn && lista.findIndex((otra) => otra?.id === cuenta.id) === indice
  );

  const usuarioGuardado = await autenticacionRepositorio.ejecutarEnTransaccion(async (db) => {
    for (const cuenta of cuentasEliminadasALiberar) {
      await autenticacionRepositorio.actualizar(
        cuenta!.id,
        {
          correo: archivarCorreoEliminado(cuenta!.correo, cuenta!.id),
          rut: null
        },
        db
      );
    }

    return autenticacionRepositorio.crear(
      {
        nombre: datos.nombre.trim(),
        correo: correoNormalizado,
        rut,
        rol: rolAsignado,
        contrasenaHash,
        cuentaActiva: true,
        correoVerificado: false,
        registroParcial: false,
        debeCambiarContrasena: false,
        tokenVerificacionCorreo,
        tokenVerificacionCorreoExpiraEn
      },
      db
    );
  });
  const enlace = `${entorno.app.urlFrontend}/verificar-correo?token=${tokenVerificacion}`;
  const correo = crearCorreoVerificacion(usuarioGuardado.nombre, enlace);

  await enviarCorreo({
    para: usuarioGuardado.correo,
    asunto: correo.asunto,
    texto: correo.texto,
    html: correo.html
  });

  await notificarUsuariosPorRol({
    roles: [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR],
    titulo: 'Nuevo registro pendiente',
    mensaje: `${usuarioGuardado.nombre} solicitó una cuenta ${usuarioGuardado.rol}. Revisa la solicitud para gestionar el acceso.`,
    tipo: TipoNotificacion.CUENTA,
    datos: { usuarioId: usuarioGuardado.id, rol: usuarioGuardado.rol }
  });

  await registrarAuditoria({
    actorUsuarioId: usuarioGuardado.id,
    accion: 'CUENTA_REGISTRADA',
    entidad: 'usuarios',
    entidadId: usuarioGuardado.id,
    datos: {
      correo: usuarioGuardado.correo,
      rol: usuarioGuardado.rol,
      identificadoresLiberados: cuentasEliminadasALiberar.map((cuenta) => cuenta!.id)
    }
  });

  return {
    message: 'Registro recibido. Revisa tu correo para activar la cuenta.',
    usuario: mapearUsuarioPublico(usuarioGuardado)
  };
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

  if (!usuario.cuentaActiva) {
    await registrarAuditoria({
      actorUsuarioId: usuario.id,
      accion: 'LOGIN_BLOQUEADO',
      entidad: 'usuarios',
      entidadId: usuario.id,
      datos: { motivo: 'cuenta_desactivada' }
    });
    throw new ErrorHttp(403, 'La cuenta está desactivada');
  }

  if (usuario.registroParcial) {
    await registrarAuditoria({
      actorUsuarioId: usuario.id,
      accion: 'LOGIN_BLOQUEADO',
      entidad: 'usuarios',
      entidadId: usuario.id,
      datos: { motivo: 'registro_parcial' }
    });
    throw new ErrorHttp(403, 'Debes completar tu registro antes de iniciar sesión');
  }

  if (!usuario.correoVerificado) {
    await registrarAuditoria({
      actorUsuarioId: usuario.id,
      accion: 'LOGIN_BLOQUEADO',
      entidad: 'usuarios',
      entidadId: usuario.id,
      datos: { motivo: 'correo_no_verificado' }
    });
    throw new ErrorHttp(403, 'Debes verificar tu correo antes de iniciar sesión');
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

  await registrarAuditoria({
    actorUsuarioId: usuario.id,
    accion: 'LOGIN_EXITOSO',
    entidad: 'usuarios',
    entidadId: usuario.id
  });

  const token = crearTokenSesion(usuario.id, usuario.rol, usuario.versionSesion);
  const refreshToken = crearRefreshToken();
  await guardarRefreshToken(usuario.id, refreshToken, usuario.versionSesion);

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

export const verificarCorreo = async (token: string) => {
  const usuario = await autenticacionRepositorio.buscarPorTokenVerificacion(hashearToken(token));

  if (!usuario) {
    throw new ErrorHttp(400, 'El enlace de verificación no es válido');
  }

  if (usuario.registroParcial) {
    throw new ErrorHttp(409, 'Debes completar tu registro antes de activar la cuenta');
  }

  if (
    !usuario.tokenVerificacionCorreoExpiraEn ||
    usuario.tokenVerificacionCorreoExpiraEn.getTime() < Date.now()
  ) {
    await autenticacionRepositorio.limpiarTokenVerificacion(usuario.id);
    throw new ErrorHttp(400, 'El enlace de verificación expiró. Solicita un nuevo registro.');
  }

  const usuarioGuardado = await autenticacionRepositorio.marcarCorreoVerificado(usuario.id);

  await crearNotificacion({
    usuarioId: usuarioGuardado.id,
    titulo: 'Cuenta activada',
    mensaje: 'Tu cuenta está lista para usar UBBike.',
    tipo: TipoNotificacion.CUENTA
  });

  const correoCuentaVerificada = crearCorreoCuentaVerificada(usuarioGuardado.nombre);
  await enviarCorreo({
    para: usuarioGuardado.correo,
    asunto: correoCuentaVerificada.asunto,
    texto: correoCuentaVerificada.texto,
    html: correoCuentaVerificada.html
  });

  await registrarAuditoria({
    actorUsuarioId: usuarioGuardado.id,
    accion: 'CORREO_VERIFICADO',
    entidad: 'usuarios',
    entidadId: usuarioGuardado.id
  });

  return {
    message: 'Correo verificado correctamente',
    usuario: mapearUsuarioPublico(usuarioGuardado)
  };
};

export const completarRegistro = async (datos: DatosCompletarRegistro) => {
  const usuario = await autenticacionRepositorio.buscarRegistroParcialPorToken(
    hashearToken(datos.token)
  );

  if (!usuario) {
    throw new ErrorHttp(400, 'El enlace de registro no es válido');
  }

  if (
    !usuario.tokenVerificacionCorreoExpiraEn ||
    usuario.tokenVerificacionCorreoExpiraEn.getTime() < Date.now()
  ) {
    await autenticacionRepositorio.limpiarTokenVerificacion(usuario.id);
    throw new ErrorHttp(400, 'El enlace de registro expiró. Solicita apoyo a un guardia.');
  }

  const usuarioGuardado = await autenticacionRepositorio.completarRegistroParcial(usuario.id, {
    nombre: datos.nombre,
    contrasenaHash: await bcrypt.hash(datos.contrasena, 12)
  });

  await crearNotificacion({
    usuarioId: usuarioGuardado.id,
    titulo: 'Cuenta activada',
    mensaje: 'Completaste tu registro. Tu cuenta está lista para usar UBBike.',
    tipo: TipoNotificacion.CUENTA
  });

  const correoCuentaVerificada = crearCorreoCuentaVerificada(usuarioGuardado.nombre);
  await enviarCorreo({
    para: usuarioGuardado.correo,
    asunto: correoCuentaVerificada.asunto,
    texto: correoCuentaVerificada.texto,
    html: correoCuentaVerificada.html
  });

  await registrarAuditoria({
    actorUsuarioId: usuarioGuardado.id,
    accion: 'REGISTRO_PARCIAL_COMPLETADO',
    entidad: 'usuarios',
    entidadId: usuarioGuardado.id
  });

  return {
    message: 'Registro completado correctamente',
    usuario: mapearUsuarioPublico(usuarioGuardado)
  };
};

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

  const enlace = `${entorno.app.urlFrontend}/cambiar-contrasena?token=${tokenCambioContrasena}`;
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
  await revocarTodosLosRefreshTokens(usuario.id);

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
    message: 'Contraseña actualizada correctamente'
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

  await revocarTodosLosRefreshTokens(usuario.id);

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

export const cerrarSesion = async (usuarioId: string, refreshTokenRecibido?: string) => {
  if (refreshTokenRecibido) {
    await revocarRefreshToken(usuarioId, refreshTokenRecibido);
  } else {
    await revocarTodosLosRefreshTokens(usuarioId);
  }

  await autenticacionRepositorio.actualizar(usuarioId, {
    versionSesion: { increment: 1 }
  });

  await registrarAuditoria({
    actorUsuarioId: usuarioId,
    accion: 'LOGOUT',
    entidad: 'usuarios',
    entidadId: usuarioId
  });

  return { message: 'Sesión cerrada correctamente' };
};
