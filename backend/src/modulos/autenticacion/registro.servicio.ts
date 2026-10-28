import bcrypt from 'bcryptjs';
import { ErrorHttp } from '../../comun/errores/error-http';
import { crearEnlaceCorreo } from '../enlaces/enlace.servicio';
import { registrarAuditoria } from '../auditoria/auditoria.servicio';
import { crearCorreoCuentaVerificada, crearCorreoVerificacion } from '../correos/cuenta.plantillas';
import { enviarCorreo } from '../correos/correo.servicio';
import {
  crearNotificacion,
  notificarUsuariosPorRol
} from '../notificaciones/notificacion.servicio';
import { TipoNotificacion } from '../notificaciones/tipo-notificacion';
import { mapearUsuarioPublico } from '../usuarios/usuario.mapeador';
import { RolUsuario } from '../usuarios/rol-usuario';
import {
  crearTokenSeguro,
  hashearToken,
  horasExpiracionVerificacionCorreo,
  resolverRolRegistrable
} from './autenticacion.tokens';
import * as autenticacionRepositorio from './autenticacion.repositorio';

type DatosRegistro = {
  nombre: string;
  rut?: string;
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
  const enlace = crearEnlaceCorreo('verificar-correo', tokenVerificacion);
  const correo = crearCorreoVerificacion(
    usuarioGuardado.nombre,
    usuarioGuardado.correo,
    enlace,
    tokenVerificacionCorreoExpiraEn
  );

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

type CuentaPorConfirmar = {
  id: string;
  nombre: string;
  correo: string;
  correoVerificado: boolean;
  registroParcial: boolean;
  debeCambiarContrasena: boolean;
  cuentaActiva: boolean;
  eliminadoEn: Date | null;
  tokenVerificacionCorreoExpiraEn: Date | null;
};

const esperaEntreReenviosMs = 60 * 1000;

export const mensajeReenvioVerificacion =
  'Si hay una cuenta pendiente de confirmar con ese correo, te enviamos un enlace nuevo.';

const puedeConfirmarCorreo = (usuario: CuentaPorConfirmar) =>
  !usuario.correoVerificado &&
  !usuario.registroParcial &&
  !usuario.debeCambiarContrasena &&
  usuario.cuentaActiva &&
  !usuario.eliminadoEn;

const enviarNuevoEnlaceVerificacion = async (usuario: CuentaPorConfirmar) => {
  const duracionMs = 1000 * 60 * 60 * horasExpiracionVerificacionCorreo;
  const emitidoEn = usuario.tokenVerificacionCorreoExpiraEn
    ? usuario.tokenVerificacionCorreoExpiraEn.getTime() - duracionMs
    : 0;
  if (Date.now() - emitidoEn < esperaEntreReenviosMs) {
    return;
  }

  const token = crearTokenSeguro();
  const venceEn = new Date(Date.now() + duracionMs);
  await autenticacionRepositorio.actualizar(usuario.id, {
    tokenVerificacionCorreo: hashearToken(token),
    tokenVerificacionCorreoExpiraEn: venceEn
  });

  const correo = crearCorreoVerificacion(
    usuario.nombre,
    usuario.correo,
    crearEnlaceCorreo('verificar-correo', token),
    venceEn
  );
  await enviarCorreo({
    para: usuario.correo,
    asunto: correo.asunto,
    texto: correo.texto,
    html: correo.html
  });

  await registrarAuditoria({
    actorUsuarioId: usuario.id,
    accion: 'CORREO_VERIFICACION_REENVIADO',
    entidad: 'usuarios',
    entidadId: usuario.id
  });
};

export const reenviarVerificacion = async (correo: string) => {
  const usuario = await autenticacionRepositorio.buscarPorCorreo(correo.trim().toLowerCase());
  if (usuario && puedeConfirmarCorreo(usuario)) {
    await enviarNuevoEnlaceVerificacion(usuario);
  }
  return { message: mensajeReenvioVerificacion };
};

export const reenviarVerificacionConEnlace = async (token: string) => {
  const usuario = await autenticacionRepositorio.buscarPorTokenVerificacion(hashearToken(token));
  if (!usuario || !puedeConfirmarCorreo(usuario)) {
    return false;
  }
  await enviarNuevoEnlaceVerificacion(usuario);
  return true;
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
    throw new ErrorHttp(
      400,
      'El enlace de verificación expiró. Pide al administrador que te reenvíe el correo de verificación.'
    );
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
