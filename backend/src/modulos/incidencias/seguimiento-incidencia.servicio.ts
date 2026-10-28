import { ErrorHttp } from '../../comun/errores/error-http';
import { registrarAuditoria } from '../auditoria/auditoria.servicio';
import {
  crearNotificacion,
  ejecutarEfectosDiferidos,
  notificarUsuariosPorRol,
  type EfectosDiferidos
} from '../notificaciones/notificacion.servicio';
import { TipoNotificacion } from '../notificaciones/tipo-notificacion';
import { RolUsuario } from '../usuarios/rol-usuario';
import { crearCorreoIncidenciaResuelta } from '../correos/operacion.plantillas';
import { enviarCorreo } from '../correos/correo.servicio';
import {
  EventosTiempoReal,
  emitirTiempoReal,
  salaRol,
  salaUsuario
} from '../../tiempo-real/tiempo-real';
import { EstadoIncidencia } from './estado-incidencia';
import * as incidenciaRepositorio from './incidencia.repositorio';
import {
  rolesCentral,
  estadosCerradosIncidencia,
  calcularSegundosParaRecordatorioIncidencia
} from './incidencia.reglas';
import {
  etiquetaEstadoIncidencia,
  etiquetaTipoIncidencia,
  mapearIncidencia
} from './incidencia.mapeador';
import { enviarCorreosCentralIncidencia } from './incidencia.servicio';

type DatosActualizarIncidencia = {
  usuarioId: string;
  rol: string;
  incidenciaId: string;
  estado: EstadoIncidencia;
  respuesta?: string | null;
  ip?: string | null;
  userAgent?: string | null;
};

type DatosRecordarIncidencia = {
  usuarioId: string;
  rol: string;
  incidenciaId: string;
};

export const actualizarEstadoIncidencia = async (datos: DatosActualizarIncidencia) => {
  if (!rolesCentral.includes(datos.rol)) {
    throw new ErrorHttp(403, 'Solo administracion puede gestionar incidencias');
  }

  const efectos: EfectosDiferidos = [];
  const resultado = await incidenciaRepositorio.ejecutarEnTransaccion(async (db) => {
    const incidencia = await incidenciaRepositorio.buscarPorId(datos.incidenciaId, db);

    if (!incidencia) {
      throw new ErrorHttp(404, 'Incidencia no encontrada');
    }

    if (estadosCerradosIncidencia.includes(incidencia.estado)) {
      throw new ErrorHttp(409, 'La incidencia ya está cerrada');
    }

    const respuesta = datos.respuesta?.trim() || null;
    const cerrada = estadosCerradosIncidencia.includes(datos.estado);

    if (cerrada && !respuesta) {
      throw new ErrorHttp(400, 'Debes indicar una respuesta para cerrar la incidencia');
    }

    const ahora = new Date();

    const actualizada = await incidenciaRepositorio.actualizar(
      incidencia.id,
      {
        estado: datos.estado,
        respuesta: respuesta ?? incidencia.respuesta,
        gestionadaPorUsuarioId: datos.usuarioId,
        resueltaEn: cerrada ? ahora : null
      },
      db
    );

    const notificarReportante = incidencia.reportadaPorUsuarioId !== datos.usuarioId;

    if (notificarReportante) {
      await crearNotificacion(
        {
          usuarioId: incidencia.reportadaPorUsuarioId,
          titulo: 'Incidencia actualizada',
          mensaje: `El estado del reporte en ${incidencia.bicicletero.nombre} cambió a ${etiquetaEstadoIncidencia(datos.estado)}.`,
          tipo: TipoNotificacion.INCIDENCIA,
          datos: { incidenciaId: incidencia.id, estado: datos.estado }
        },
        db,
        efectos
      );
    }

    if (notificarReportante && cerrada && respuesta) {
      const correo = crearCorreoIncidenciaResuelta({
        nombre: incidencia.reportadaPorUsuario.nombre,
        tipo: etiquetaTipoIncidencia(incidencia.tipo),
        bicicletero: incidencia.bicicletero.nombre,
        estado: etiquetaEstadoIncidencia(datos.estado),
        respuesta,
        fecha: ahora
      });
      await enviarCorreo(
        { para: incidencia.reportadaPorUsuario.correo, ...correo, referencia: incidencia.id },
        db
      );
    }

    await registrarAuditoria(
      {
        actorUsuarioId: datos.usuarioId,
        accion: 'INCIDENCIA_ESTADO_ACTUALIZADO',
        entidad: 'incidencias',
        entidadId: incidencia.id,
        ip: datos.ip,
        userAgent: datos.userAgent,
        datos: {
          estadoAnterior: incidencia.estado,
          estadoNuevo: datos.estado,
          respuesta: respuesta ?? undefined
        }
      },
      db
    );

    return mapearIncidencia(actualizada, { usuarioId: datos.usuarioId, rol: datos.rol });
  });

  ejecutarEfectosDiferidos(efectos);
  const reportanteId = resultado.reportadaPorUsuario?.id;
  emitirTiempoReal(
    [
      ...(reportanteId ? [salaUsuario(reportanteId)] : []),
      salaRol(RolUsuario.GUARDIA),
      salaRol(RolUsuario.ADMIN_CENTRAL),
      salaRol(RolUsuario.ADMINISTRADOR)
    ],
    EventosTiempoReal.INCIDENCIA
  );

  return resultado;
};

export const recordarIncidencia = async (datos: DatosRecordarIncidencia) => {
  const efectos: EfectosDiferidos = [];
  const resultado = await incidenciaRepositorio.ejecutarEnTransaccion(async (db) => {
    const incidencia = await incidenciaRepositorio.buscarPorId(datos.incidenciaId, db);

    if (!incidencia) {
      throw new ErrorHttp(404, 'Incidencia no encontrada');
    }

    if (incidencia.reportadaPorUsuarioId !== datos.usuarioId) {
      throw new ErrorHttp(403, 'Solo quien reportó la incidencia puede recordarla');
    }

    if (estadosCerradosIncidencia.includes(incidencia.estado)) {
      throw new ErrorHttp(409, 'La incidencia ya está cerrada');
    }

    const segundosRestantes = calcularSegundosParaRecordatorioIncidencia(incidencia);

    if (segundosRestantes !== null && segundosRestantes > 0) {
      throw new ErrorHttp(409, `Podrás recordar nuevamente en ${segundosRestantes} segundos`);
    }

    const ahora = new Date();
    const actualizada = await incidenciaRepositorio.actualizar(
      incidencia.id,
      {
        ultimoRecordatorioEn: ahora,
        recordatorios: { increment: 1 }
      },
      db
    );

    await notificarUsuariosPorRol(
      {
        roles: [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR],
        titulo: 'Recordatorio de incidencia',
        mensaje: `${incidencia.reportadaPorUsuario.nombre} sigue esperando respuesta en ${incidencia.bicicletero.nombre}.`,
        tipo: TipoNotificacion.INCIDENCIA,
        datos: { incidenciaId: incidencia.id, bicicleteroId: incidencia.bicicletero.id },
        excluirUsuarioId: datos.usuarioId
      },
      db,
      efectos
    );

    await registrarAuditoria(
      {
        actorUsuarioId: datos.usuarioId,
        accion: 'INCIDENCIA_RECORDADA',
        entidad: 'incidencias',
        entidadId: incidencia.id,
        datos: { rolActor: datos.rol }
      },
      db
    );

    await enviarCorreosCentralIncidencia(incidencia, db, true, datos.usuarioId);
    return mapearIncidencia(actualizada, { usuarioId: datos.usuarioId, rol: datos.rol });
  });

  ejecutarEfectosDiferidos(efectos);
  const reportanteId = resultado.reportadaPorUsuario?.id;
  emitirTiempoReal(
    [
      ...(reportanteId ? [salaUsuario(reportanteId)] : []),
      salaRol(RolUsuario.GUARDIA),
      salaRol(RolUsuario.ADMIN_CENTRAL),
      salaRol(RolUsuario.ADMINISTRADOR)
    ],
    EventosTiempoReal.INCIDENCIA
  );

  return resultado;
};
