import bcrypt from 'bcryptjs';
import { ErrorHttp } from '../../comun/errores/error-http';
import { liberarBicicleteroGuardia } from '../acceso/asignaciones/asignacion-guardia.servicio';
import * as usuarioRepositorio from './usuario.repositorio';
import { registrarAuditoria } from '../auditoria/auditoria.servicio';
import {
  crearCorreoCuentaAdministrativa,
  crearCorreoCuentaDesactivada
} from '../correos/cuenta.plantillas';
import { enviarCorreo } from '../correos/correo.servicio';
import { crearNotificacion } from '../notificaciones/notificacion.servicio';
import { TipoNotificacion } from '../notificaciones/tipo-notificacion';
import { mapearUsuarioPublico } from './usuario.mapeador';
import { RolUsuario } from './rol-usuario';
import { validarCorreoParaRol } from './usuario.reglas';
import { emitirCambioUsuarios } from './usuario.eventos';
import {
  crearTokenSeguro,
  horasExpiracionVerificacionCorreo
} from '../autenticacion/autenticacion.tokens';
import { crearDatosInvitacionAcceso } from './invitacion.servicio';

type DatosCrearUsuario = {
  nombre: string;
  correo: string;
  rut?: string | null;
  rol: RolUsuario;
};

type FiltrosListarUsuarios = {
  q?: string;
  rol?: RolUsuario;
  cuentaActiva?: boolean;
  correoVerificado?: boolean;
};

export const asegurarNoEsUltimoAdministrador = async (usuarioId: string) => {
  const administradoresRestantes = await usuarioRepositorio.contarAdministradoresActivos(usuarioId);

  if (administradoresRestantes === 0) {
    throw new ErrorHttp(400, 'Debe existir al menos un administrador activo y verificado');
  }
};

export const listarUsuarios = async (filtros: FiltrosListarUsuarios = {}) => {
  const usuarios = await usuarioRepositorio.buscarUsuarios(filtros);

  return usuarios.map(mapearUsuarioPublico);
};

export const crearUsuarioAdmin = async (datos: DatosCrearUsuario, actorUsuarioId?: string) => {
  const correoNormalizado = datos.correo.trim().toLowerCase();
  const rut = datos.rut?.trim() ? datos.rut.trim() : null;

  validarCorreoParaRol(correoNormalizado, datos.rol);

  const porCorreo = await usuarioRepositorio.buscarPorCorreo(correoNormalizado);
  const porRut = rut ? await usuarioRepositorio.buscarPorRut(rut) : null;

  if (porCorreo && !porCorreo.eliminadoEn) {
    throw new ErrorHttp(409, 'El correo ya está registrado');
  }
  if (porRut && !porRut.eliminadoEn) {
    throw new ErrorHttp(409, 'El RUT ya está registrado');
  }

  const { tokenCambioContrasenaHash, tokenCambioContrasenaExpiraEn, enlaceDefinirContrasena } =
    crearDatosInvitacionAcceso();
  const contrasenaHash = await bcrypt.hash(crearTokenSeguro(), 12);

  if (porCorreo?.eliminadoEn && porRut?.eliminadoEn && porCorreo.id !== porRut.id) {
    throw new ErrorHttp(
      409,
      'El correo y el RUT pertenecen a cuentas eliminadas distintas. Revisa el caso antes de reactivar.'
    );
  }

  const cuentaEliminada = porRut?.eliminadoEn ? porRut : porCorreo?.eliminadoEn ? porCorreo : null;
  if (cuentaEliminada) {
    const usuarioRestaurado = await usuarioRepositorio.actualizar(cuentaEliminada.id, {
      nombre: datos.nombre.trim(),
      correo: correoNormalizado,
      rut,
      rol: datos.rol,
      contrasenaHash,
      correoVerificado: false,
      registroParcial: false,
      debeCambiarContrasena: true,
      cuentaActiva: true,
      eliminadoEn: null,
      tokenVerificacionCorreo: null,
      tokenVerificacionCorreoExpiraEn: null,
      tokenCambioContrasena: tokenCambioContrasenaHash,
      tokenCambioContrasenaExpiraEn,
      versionSesion: {
        increment: 1
      }
    });

    await crearNotificacion({
      usuarioId: usuarioRestaurado.id,
      titulo: 'Cuenta reactivada',
      mensaje: 'Administración reactivó tu cuenta UBBike.',
      tipo: TipoNotificacion.CUENTA,
      datos: {
        rol: usuarioRestaurado.rol,
        cuentaActiva: usuarioRestaurado.cuentaActiva,
        correoVerificado: usuarioRestaurado.correoVerificado
      }
    });

    const correoInvitacion = crearCorreoCuentaAdministrativa(
      usuarioRestaurado.nombre,
      enlaceDefinirContrasena,
      horasExpiracionVerificacionCorreo,
      usuarioRestaurado.rol
    );
    await enviarCorreo({
      para: usuarioRestaurado.correo,
      asunto: correoInvitacion.asunto,
      texto: correoInvitacion.texto,
      html: correoInvitacion.html
    });

    await registrarAuditoria({
      actorUsuarioId: actorUsuarioId ?? null,
      accion: 'USUARIO_RESTAURADO_ADMIN',
      entidad: 'usuarios',
      entidadId: usuarioRestaurado.id,
      datos: {
        correo: usuarioRestaurado.correo,
        rol: usuarioRestaurado.rol,
        invitacionCorreo: true
      }
    });

    emitirCambioUsuarios();

    return mapearUsuarioPublico(usuarioRestaurado);
  }

  const usuarioGuardado = await usuarioRepositorio.crear({
    nombre: datos.nombre.trim(),
    correo: correoNormalizado,
    rut,
    rol: datos.rol,
    contrasenaHash,
    correoVerificado: false,
    registroParcial: false,
    debeCambiarContrasena: true,
    cuentaActiva: true,
    tokenCambioContrasena: tokenCambioContrasenaHash,
    tokenCambioContrasenaExpiraEn
  });

  await crearNotificacion({
    usuarioId: usuarioGuardado.id,
    titulo: 'Cuenta creada',
    mensaje: 'Administración creó tu cuenta UBBike. Revisa tu correo para crear tu contraseña.',
    tipo: TipoNotificacion.CUENTA,
    datos: {
      rol: usuarioGuardado.rol,
      cuentaActiva: usuarioGuardado.cuentaActiva,
      correoVerificado: usuarioGuardado.correoVerificado
    }
  });

  const correoInvitacion = crearCorreoCuentaAdministrativa(
    usuarioGuardado.nombre,
    enlaceDefinirContrasena,
    horasExpiracionVerificacionCorreo,
    usuarioGuardado.rol
  );
  await enviarCorreo({
    para: usuarioGuardado.correo,
    asunto: correoInvitacion.asunto,
    texto: correoInvitacion.texto,
    html: correoInvitacion.html
  });

  await registrarAuditoria({
    actorUsuarioId: actorUsuarioId ?? null,
    accion: 'USUARIO_CREADO_ADMIN',
    entidad: 'usuarios',
    entidadId: usuarioGuardado.id,
    datos: {
      correo: usuarioGuardado.correo,
      rol: usuarioGuardado.rol,
      invitacionCorreo: true
    }
  });

  emitirCambioUsuarios();

  return mapearUsuarioPublico(usuarioGuardado);
};

export const eliminarUsuarioAdmin = async (usuarioId: string, actorUsuarioId?: string) => {
  if (usuarioId === actorUsuarioId) {
    throw new ErrorHttp(400, 'No puedes eliminar tu propia cuenta');
  }

  const usuario = await usuarioRepositorio.buscarPorId(usuarioId);
  if (!usuario) {
    throw new ErrorHttp(404, 'Usuario no encontrado');
  }
  if (usuario.eliminadoEn) {
    throw new ErrorHttp(409, 'La cuenta ya fue eliminada');
  }
  if (usuario.rol === RolUsuario.ADMINISTRADOR) {
    await asegurarNoEsUltimoAdministrador(usuario.id);
  }

  const usuarioGuardado = await usuarioRepositorio.actualizar(usuario.id, {
    cuentaActiva: false,
    eliminadoEn: new Date(),
    tokenVerificacionCorreo: null,
    tokenVerificacionCorreoExpiraEn: null,
    tokenCambioContrasena: null,
    tokenCambioContrasenaExpiraEn: null,
    versionSesion: { increment: 1 }
  });

  if (usuario.rol === RolUsuario.GUARDIA) {
    await liberarBicicleteroGuardia(usuario.id, actorUsuarioId ?? null);
  }

  const correoCuentaDesactivada = crearCorreoCuentaDesactivada(usuarioGuardado.nombre);
  await enviarCorreo({
    para: usuarioGuardado.correo,
    asunto: correoCuentaDesactivada.asunto,
    texto: correoCuentaDesactivada.texto,
    html: correoCuentaDesactivada.html
  });

  await registrarAuditoria({
    actorUsuarioId: actorUsuarioId ?? null,
    accion: 'USUARIO_ELIMINADO_ADMIN',
    entidad: 'usuarios',
    entidadId: usuarioGuardado.id,
    datos: { correo: usuarioGuardado.correo }
  });

  emitirCambioUsuarios();

  return { message: 'Cuenta eliminada (desactivada y sesiones cerradas)' };
};
