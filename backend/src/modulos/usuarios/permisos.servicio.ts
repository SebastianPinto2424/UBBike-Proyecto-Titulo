import { ErrorHttp } from '../../comun/errores/error-http';
import { liberarBicicleteroGuardia } from '../acceso/asignaciones/asignacion-guardia.servicio';
import { crearEnlaceCorreo } from '../enlaces/enlace.servicio';
import * as usuarioRepositorio from './usuario.repositorio';
import { registrarAuditoria } from '../auditoria/auditoria.servicio';
import {
  crearCorreoCuentaAdministrativa,
  crearCorreoCuentaDesactivada,
  crearCorreoCuentaReactivada,
  crearCorreoRolActualizado,
  crearCorreoNuevoCorreo
} from '../correos/cuenta.plantillas';
import { enviarCorreo } from '../correos/correo.servicio';
import { etiquetaRol } from '../correos/correo.formato';
import { crearNotificacion } from '../notificaciones/notificacion.servicio';
import { TipoNotificacion } from '../notificaciones/tipo-notificacion';
import { mapearUsuarioPublico } from './usuario.mapeador';
import { RolUsuario } from './rol-usuario';
import { validarCorreoParaRol } from './usuario.reglas';
import {
  crearTokenSeguro,
  hashearToken,
  horasExpiracionVerificacionCorreo
} from '../autenticacion/autenticacion.tokens';
import { asegurarNoEsUltimoAdministrador } from './usuario.servicio';
import { emitirCambioUsuarios } from './usuario.eventos';
import { crearDatosInvitacionAcceso } from './invitacion.servicio';

type DatosActualizarPermisos = {
  nombre?: string;
  correo?: string;
  rut?: string | null;
  rol?: RolUsuario;
  cuentaActiva?: boolean;
};

export const actualizarPermisosUsuario = async (
  usuarioId: string,
  datos: DatosActualizarPermisos,
  actorUsuarioId?: string
) => {
  const usuario = await usuarioRepositorio.buscarPorId(usuarioId);

  if (!usuario) {
    throw new ErrorHttp(404, 'Usuario no encontrado');
  }
  if (usuario.eliminadoEn) {
    throw new ErrorHttp(409, 'No puedes modificar una cuenta eliminada');
  }

  const correoCambia =
    datos.correo !== undefined && usuario.correo !== datos.correo.trim().toLowerCase();
  const rolCambia = datos.rol !== undefined && usuario.rol !== datos.rol;

  if (correoCambia || rolCambia) {
    validarCorreoParaRol(datos.correo ?? usuario.correo, datos.rol ?? usuario.rol);
  }
  const cuentaActivaCambia =
    datos.cuentaActiva !== undefined && usuario.cuentaActiva !== datos.cuentaActiva;
  const dejaDeSerAdministradorActivo =
    usuario.rol === RolUsuario.ADMINISTRADOR &&
    ((datos.rol !== undefined && datos.rol !== RolUsuario.ADMINISTRADOR) ||
      datos.cuentaActiva === false ||
      correoCambia);

  if (dejaDeSerAdministradorActivo) {
    await asegurarNoEsUltimoAdministrador(usuario.id);
  }

  let invalidarSesiones = false;

  const datosActualizacion: {
    nombre?: string;
    correo?: string;
    rut?: string | null;
    rol?: RolUsuario;
    cuentaActiva?: boolean;
    correoVerificado?: boolean;
    tokenVerificacionCorreo?: string | null;
    tokenVerificacionCorreoExpiraEn?: Date | null;
    tokenCambioContrasena?: string | null;
    tokenCambioContrasenaExpiraEn?: Date | null;
    versionSesion?: {
      increment: number;
    };
  } = {};

  let correoVerificacionPendiente:
    | {
        token: string;
        venceEn: Date;
      }
    | undefined;
  let correoAccesoPendiente:
    | {
        enlace: string;
      }
    | undefined;

  if (datos.rol !== undefined) {
    invalidarSesiones = invalidarSesiones || usuario.rol !== datos.rol;
    datosActualizacion.rol = datos.rol;
  }

  if (datos.nombre !== undefined) {
    datosActualizacion.nombre = datos.nombre;
  }

  if (datos.correo !== undefined) {
    const correoNormalizado = datos.correo.trim().toLowerCase();
    const correoExistente = await usuarioRepositorio.buscarPorCorreo(correoNormalizado);
    if (correoExistente && correoExistente.id !== usuario.id) {
      throw new ErrorHttp(409, 'El correo ya está registrado');
    }
    invalidarSesiones = invalidarSesiones || usuario.correo !== correoNormalizado;
    datosActualizacion.correo = correoNormalizado;
    if (usuario.correo !== correoNormalizado) {
      datosActualizacion.correoVerificado = false;
      datosActualizacion.tokenVerificacionCorreo = null;
      datosActualizacion.tokenVerificacionCorreoExpiraEn = null;

      if (usuario.debeCambiarContrasena) {
        const {
          tokenCambioContrasenaHash,
          tokenCambioContrasenaExpiraEn,
          enlaceDefinirContrasena
        } = crearDatosInvitacionAcceso();
        datosActualizacion.tokenCambioContrasena = tokenCambioContrasenaHash;
        datosActualizacion.tokenCambioContrasenaExpiraEn = tokenCambioContrasenaExpiraEn;
        correoAccesoPendiente = {
          enlace: enlaceDefinirContrasena
        };
      } else {
        const tokenVerificacion = crearTokenSeguro();
        const venceEn = new Date(Date.now() + 1000 * 60 * 60 * horasExpiracionVerificacionCorreo);
        datosActualizacion.tokenVerificacionCorreo = hashearToken(tokenVerificacion);
        datosActualizacion.tokenVerificacionCorreoExpiraEn = venceEn;
        correoVerificacionPendiente = {
          token: tokenVerificacion,
          venceEn
        };
      }
    }
  }

  if (datos.rut !== undefined) {
    const rut = datos.rut?.trim() ? datos.rut.trim() : null;
    if (rut) {
      const rutExistente = await usuarioRepositorio.buscarPorRut(rut);
      if (rutExistente && rutExistente.id !== usuario.id) {
        throw new ErrorHttp(409, 'El RUT ya está registrado');
      }
    }
    datosActualizacion.rut = rut;
  }

  if (datos.cuentaActiva !== undefined) {
    invalidarSesiones = invalidarSesiones || usuario.cuentaActiva !== datos.cuentaActiva;
    datosActualizacion.cuentaActiva = datos.cuentaActiva;
  }

  if (invalidarSesiones) {
    datosActualizacion.versionSesion = {
      increment: 1
    };
  }

  const usuarioGuardado = await usuarioRepositorio.actualizar(usuario.id, datosActualizacion);

  if (
    usuario.rol === RolUsuario.GUARDIA &&
    (usuarioGuardado.rol !== RolUsuario.GUARDIA || !usuarioGuardado.cuentaActiva)
  ) {
    await liberarBicicleteroGuardia(usuario.id, actorUsuarioId ?? null);
  }

  if (correoAccesoPendiente) {
    const correoInvitacion = crearCorreoCuentaAdministrativa(
      usuarioGuardado.nombre,
      correoAccesoPendiente.enlace,
      horasExpiracionVerificacionCorreo,
      usuarioGuardado.rol
    );
    await enviarCorreo({
      para: usuarioGuardado.correo,
      asunto: correoInvitacion.asunto,
      texto: correoInvitacion.texto,
      html: correoInvitacion.html
    });
  }

  if (correoVerificacionPendiente) {
    const enlace = crearEnlaceCorreo('verificar-correo', correoVerificacionPendiente.token);
    const correo = crearCorreoNuevoCorreo(
      usuarioGuardado.nombre,
      usuarioGuardado.correo,
      enlace,
      correoVerificacionPendiente.venceEn
    );
    await enviarCorreo({
      para: usuarioGuardado.correo,
      asunto: correo.asunto,
      texto: correo.texto,
      html: correo.html
    });
  }

  if (cuentaActivaCambia) {
    const correoCuenta = usuarioGuardado.cuentaActiva
      ? crearCorreoCuentaReactivada(usuarioGuardado.nombre)
      : crearCorreoCuentaDesactivada(usuarioGuardado.nombre);

    await enviarCorreo({
      para: usuarioGuardado.correo,
      asunto: correoCuenta.asunto,
      texto: correoCuenta.texto,
      html: correoCuenta.html
    });
  }

  if (rolCambia) {
    const correoRol = crearCorreoRolActualizado(
      usuarioGuardado.nombre,
      usuario.rol,
      usuarioGuardado.rol
    );

    await enviarCorreo({
      para: usuarioGuardado.correo,
      asunto: correoRol.asunto,
      texto: correoRol.texto,
      html: correoRol.html
    });
  }

  await crearNotificacion({
    usuarioId: usuarioGuardado.id,
    titulo: 'Cuenta actualizada',
    mensaje: `Administración actualizó tu cuenta. Tu rol actual es ${etiquetaRol(usuarioGuardado.rol)}.`,
    tipo: TipoNotificacion.CUENTA,
    datos: {
      rol: usuarioGuardado.rol,
      cuentaActiva: usuarioGuardado.cuentaActiva,
      correoVerificado: usuarioGuardado.correoVerificado
    }
  });

  await registrarAuditoria({
    actorUsuarioId: actorUsuarioId ?? null,
    accion: 'USUARIO_ACTUALIZADO_ADMIN',
    entidad: 'usuarios',
    entidadId: usuarioGuardado.id,
    datos: {
      campos: Object.keys(datos),
      rol: usuarioGuardado.rol,
      cuentaActiva: usuarioGuardado.cuentaActiva,
      correoVerificado: usuarioGuardado.correoVerificado,
      sesionesInvalidadas: invalidarSesiones
    }
  });

  emitirCambioUsuarios();

  return mapearUsuarioPublico(usuarioGuardado);
};
