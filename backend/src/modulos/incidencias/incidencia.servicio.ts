import { randomUUID } from 'crypto';
import { ErrorHttp } from '../../comun/errors/error-http';
import { limitarPagina, validarCursor } from '../../comun/utils/paginacion';
import type { ClientePrisma } from '../../configuracion/prisma';
import { Prisma } from '../../generated/prisma/client';
import { registrarAuditoria } from '../auditoria/auditoria.servicio';
import {
  crearNotificacion,
  ejecutarEfectosDiferidos,
  notificarUsuariosPorRol,
  type EfectosDiferidos
} from '../notificaciones/notificacion.servicio';
import { TipoNotificacion } from '../notificaciones/tipo-notificacion';
import { RolUsuario } from '../usuarios/rol-usuario';
import {
  crearCorreoIncidenciaNueva,
  crearCorreoIncidenciaResuelta,
  enviarCorreo
} from '../correos/correo.servicio';
import {
  EventosTiempoReal,
  emitirTiempoReal,
  salaRol,
  salaUsuario
} from '../../tiempo-real/tiempo-real';
import { EstadoIncidencia } from './estado-incidencia';
import * as incidenciaRepositorio from './incidencia.repositorio';
import type { IncidenciaCompleta } from './incidencia.repositorio';
import {
  eliminarArchivosFotosIncidencia,
  guardarFotosIncidencia
} from './foto-incidencia.servicio';
import { TipoIncidencia } from './tipo-incidencia';

type DatosCrearIncidencia = {
  usuarioId: string;
  rol: string;
  bicicleteroId: string;
  bicicletaId?: string | null;
  tipo: TipoIncidencia;
  descripcion: string;
  fotos?: string[];
  ip?: string | null;
  userAgent?: string | null;
};

type DatosListarIncidencias = {
  usuarioId: string;
  rol: string;
  estado?: EstadoIncidencia | 'TODOS' | 'ABIERTAS';
  tipo?: TipoIncidencia | 'TODOS';
  bicicleteroId?: string;
  q?: string;
  cursor?: string;
  limite?: number;
};

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

const rolesCentral: string[] = [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR];
const estadosCerradosIncidencia: EstadoIncidencia[] = [
  EstadoIncidencia.RESUELTA,
  EstadoIncidencia.DESCARTADA
];
const segundosEsperaRecordatorioIncidencia = 300;

const etiquetaEstadoIncidencia = (estado: EstadoIncidencia) => {
  switch (estado) {
    case EstadoIncidencia.PENDIENTE:
      return 'pendiente';
    case EstadoIncidencia.EN_REVISION:
      return 'en revisión';
    case EstadoIncidencia.RESUELTA:
      return 'resuelta';
    case EstadoIncidencia.DESCARTADA:
      return 'descartada';
    default:
      return estado;
  }
};

const etiquetaTipoIncidencia = (tipo: TipoIncidencia) => {
  switch (tipo) {
    case TipoIncidencia.PROBLEMA_QR:
      return 'Problema con QR';
    case TipoIncidencia.DANO_BICICLETA:
      return 'Daño de bicicleta';
    case TipoIncidencia.DANO_INFRAESTRUCTURA:
      return 'Daño de infraestructura';
    case TipoIncidencia.PROBLEMA_MOVIMIENTO:
      return 'Problema de movimiento';
    case TipoIncidencia.USUARIO_DATOS:
      return 'Datos de usuario';
    default:
      return 'Otro';
  }
};

type ContextoIncidencia = {
  usuarioId: string;
  rol: string;
};

const calcularSegundosParaRecordatorioIncidencia = (incidencia: IncidenciaCompleta) => {
  if (estadosCerradosIncidencia.includes(incidencia.estado)) {
    return null;
  }

  const base = incidencia.ultimoRecordatorioEn ?? incidencia.creadaEn;
  const transcurridos = Math.floor((Date.now() - base.getTime()) / 1000);
  return Math.max(segundosEsperaRecordatorioIncidencia - transcurridos, 0);
};

const mapearUsuarioIncidencia = (
  usuario: IncidenciaCompleta['reportadaPorUsuario'] | IncidenciaCompleta['gestionadaPorUsuario']
) => {
  if (!usuario) {
    return null;
  }

  return {
    id: usuario.id,
    nombre: usuario.nombre,
    correo: usuario.correo,
    rut: usuario.rut,
    rol: usuario.rol
  };
};

const mapearIncidencia = (incidencia: IncidenciaCompleta, contexto: ContextoIncidencia) => {
  const esReportante = incidencia.reportadaPorUsuarioId === contexto.usuarioId;
  const segundosParaRecordar = esReportante
    ? calcularSegundosParaRecordatorioIncidencia(incidencia)
    : null;

  return {
    id: incidencia.id,
    tipo: incidencia.tipo,
    descripcion: incidencia.descripcion,
    estado: incidencia.estado,
    respuesta: incidencia.respuesta,
    creadaEn: incidencia.creadaEn,
    actualizadaEn: incidencia.actualizadaEn,
    resueltaEn: incidencia.resueltaEn,
    ultimoRecordatorioEn: incidencia.ultimoRecordatorioEn,
    recordatorios: incidencia.recordatorios,
    puedeRecordar: esReportante && segundosParaRecordar === 0,
    segundosParaRecordar,
    reportadaPorUsuario: mapearUsuarioIncidencia(incidencia.reportadaPorUsuario),
    gestionadaPorUsuario: mapearUsuarioIncidencia(incidencia.gestionadaPorUsuario),
    fotos: incidencia.fotos.map((foto) => ({
      id: foto.id,
      url: foto.fotoUrl,
      mimeType: foto.mimeType,
      tamanoBytes: foto.tamanoBytes
    })),
    bicicletero: {
      id: incidencia.bicicletero.id,
      nombre: incidencia.bicicletero.nombre,
      ubicacion: incidencia.bicicletero.ubicacion
    },
    bicicleta: incidencia.bicicleta
      ? {
          id: incidencia.bicicleta.id,
          descripcion: incidencia.bicicleta.descripcion,
          marca: incidencia.bicicleta.marca,
          modelo: incidencia.bicicleta.modelo,
          color: incidencia.bicicleta.color,
          aro: incidencia.bicicleta.aro,
          numeroSerie: incidencia.bicicleta.numeroSerie,
          fotoUrl: incidencia.bicicleta.fotoUrl,
          activa: incidencia.bicicleta.activa,
          dentroBicicletero: incidencia.bicicleta.dentroBicicletero
        }
      : null
  };
};

const obtenerBicicleterosAsignadosGuardia = async (guardiaId: string, db?: ClientePrisma) => {
  const asignaciones = await incidenciaRepositorio.buscarBicicleterosAsignados(guardiaId, db);

  return asignaciones.map((asignacion) => asignacion.bicicleteroId);
};

const asegurarBicicleteroExiste = async (bicicleteroId: string, db: ClientePrisma) => {
  const bicicletero = await incidenciaRepositorio.buscarBicicletero(bicicleteroId, db);

  if (!bicicletero) {
    throw new ErrorHttp(404, 'Bicicletero no encontrado');
  }

  return bicicletero;
};

const asegurarBicicletaValida = async (
  datos: Pick<DatosCrearIncidencia, 'usuarioId' | 'rol' | 'bicicletaId'>,
  db: ClientePrisma
) => {
  if (!datos.bicicletaId) {
    return null;
  }

  const bicicleta = await incidenciaRepositorio.buscarBicicletaActiva(datos.bicicletaId, db);

  if (!bicicleta) {
    throw new ErrorHttp(404, 'Bicicleta no encontrada');
  }

  const puedeAsociarCualquierBicicleta =
    rolesCentral.includes(datos.rol) || datos.rol === RolUsuario.GUARDIA;

  if (!puedeAsociarCualquierBicicleta && bicicleta.usuarioId !== datos.usuarioId) {
    throw new ErrorHttp(403, 'No puedes asociar una bicicleta de otro usuario');
  }

  return bicicleta;
};

const construirWhereIncidencias = async (filtros: DatosListarIncidencias) => {
  const condiciones: Prisma.IncidenciaWhereInput[] = [];

  if (rolesCentral.includes(filtros.rol)) {
  } else if (filtros.rol === RolUsuario.GUARDIA) {
    const asignados = await obtenerBicicleterosAsignadosGuardia(filtros.usuarioId);
    condiciones.push({
      OR: [
        { reportadaPorUsuarioId: filtros.usuarioId },
        ...(asignados.length ? [{ bicicleteroId: { in: asignados } }] : [])
      ]
    });
  } else {
    condiciones.push({ reportadaPorUsuarioId: filtros.usuarioId });
  }

  if (filtros.estado === 'ABIERTAS') {
    condiciones.push({ estado: { notIn: estadosCerradosIncidencia } });
  } else if (filtros.estado && filtros.estado !== 'TODOS') {
    if (!Object.values(EstadoIncidencia).includes(filtros.estado as EstadoIncidencia)) {
      throw new ErrorHttp(400, 'Estado de incidencia inválido');
    }
    condiciones.push({ estado: filtros.estado });
  }

  if (filtros.tipo && filtros.tipo !== 'TODOS') {
    if (!Object.values(TipoIncidencia).includes(filtros.tipo as TipoIncidencia)) {
      throw new ErrorHttp(400, 'Tipo de incidencia inválido');
    }
    condiciones.push({ tipo: filtros.tipo });
  }

  if (filtros.bicicleteroId) {
    condiciones.push({ bicicleteroId: filtros.bicicleteroId });
  }

  if (filtros.q) {
    const q = filtros.q.trim();
    condiciones.push({
      OR: [
        { descripcion: { contains: q, mode: 'insensitive' } },
        { respuesta: { contains: q, mode: 'insensitive' } },
        { reportadaPorUsuario: { nombre: { contains: q, mode: 'insensitive' } } },
        { reportadaPorUsuario: { correo: { contains: q, mode: 'insensitive' } } },
        { reportadaPorUsuario: { rut: { contains: q, mode: 'insensitive' } } },
        { bicicletero: { nombre: { contains: q, mode: 'insensitive' } } },
        { bicicleta: { descripcion: { contains: q, mode: 'insensitive' } } },
        { bicicleta: { numeroSerie: { contains: q, mode: 'insensitive' } } }
      ]
    });
  }

  return condiciones.length ? { AND: condiciones } : {};
};

const enviarCorreosCentralIncidencia = async (
  incidencia: IncidenciaCompleta,
  db: ClientePrisma,
  recordatorio = false,
  excluirUsuarioId?: string
) => {
  const usuarios = await incidenciaRepositorio.buscarUsuariosPorRoles(
    [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR],
    db
  );
  for (const usuario of usuarios.filter((u) => u.id !== excluirUsuarioId)) {
    const correo = crearCorreoIncidenciaNueva({
      nombreDestinatario: usuario.nombre,
      tipo: etiquetaTipoIncidencia(incidencia.tipo),
      bicicletero: incidencia.bicicletero.nombre,
      descripcion: incidencia.descripcion,
      reportadaPor: incidencia.reportadaPorUsuario.nombre,
      fecha: incidencia.creadaEn,
      recordatorio
    });
    await enviarCorreo({ para: usuario.correo, ...correo, referencia: incidencia.id }, db);
  }
};

export const crearIncidencia = async (datos: DatosCrearIncidencia) => {
  const efectos: EfectosDiferidos = [];
  const fotosGuardadas = await guardarFotosIncidencia(randomUUID(), datos.fotos ?? []);
  const nombresFotos = fotosGuardadas.map((foto) => foto.fotoNombreArchivo);

  try {
    const resultado = await incidenciaRepositorio.ejecutarEnTransaccion(async (db) => {
      const bicicletero = await asegurarBicicleteroExiste(datos.bicicleteroId, db);
      if (datos.rol === RolUsuario.GUARDIA) {
        const asignados = await obtenerBicicleterosAsignadosGuardia(datos.usuarioId, db);

        if (!asignados.includes(bicicletero.id)) {
          throw new ErrorHttp(403, 'Solo puedes reportar incidencias de tu bicicletero asignado');
        }
      }

      const bicicleta = await asegurarBicicletaValida(datos, db);
      const incidencia = await incidenciaRepositorio.crear(
        {
          reportadaPorUsuarioId: datos.usuarioId,
          bicicleteroId: bicicletero.id,
          bicicletaId: bicicleta?.id ?? null,
          tipo: datos.tipo,
          descripcion: datos.descripcion,
          ...(fotosGuardadas.length > 0
            ? {
                fotos: {
                  create: fotosGuardadas.map((foto) => ({
                    fotoUrl: foto.fotoUrl,
                    nombreArchivo: foto.fotoNombreArchivo,
                    mimeType: foto.fotoMimeType,
                    tamanoBytes: foto.fotoTamanoBytes
                  }))
                }
              }
            : {})
        },
        db
      );

      await notificarUsuariosPorRol(
        {
          roles: [RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR],
          titulo: 'Nueva incidencia reportada',
          mensaje: `Hay un reporte operativo pendiente en ${bicicletero.nombre}.`,
          tipo: TipoNotificacion.INCIDENCIA,
          datos: { incidenciaId: incidencia.id, bicicleteroId: bicicletero.id },
          excluirUsuarioId: datos.usuarioId
        },
        db,
        efectos
      );

      await crearNotificacion(
        {
          usuarioId: datos.usuarioId,
          titulo: 'Incidencia registrada',
          mensaje: `Tu reporte (${etiquetaTipoIncidencia(datos.tipo)}) en ${bicicletero.nombre} quedó registrado y fue enviado a central.`,
          tipo: TipoNotificacion.INCIDENCIA,
          datos: { incidenciaId: incidencia.id, bicicleteroId: bicicletero.id },
          soloRegistro: true
        },
        db,
        efectos
      );

      await registrarAuditoria(
        {
          actorUsuarioId: datos.usuarioId,
          accion: 'INCIDENCIA_CREADA',
          entidad: 'incidencias',
          entidadId: incidencia.id,
          ip: datos.ip,
          userAgent: datos.userAgent,
          datos: {
            tipo: datos.tipo,
            bicicleteroId: bicicletero.id,
            bicicletaId: bicicleta?.id ?? null
          }
        },
        db
      );

      await enviarCorreosCentralIncidencia(incidencia, db, false, datos.usuarioId);
      return mapearIncidencia(incidencia, { usuarioId: datos.usuarioId, rol: datos.rol });
    });

    ejecutarEfectosDiferidos(efectos);
    emitirTiempoReal(
      [
        salaRol(RolUsuario.GUARDIA),
        salaRol(RolUsuario.ADMIN_CENTRAL),
        salaRol(RolUsuario.ADMINISTRADOR)
      ],
      EventosTiempoReal.INCIDENCIA
    );

    return resultado;
  } catch (error) {
    await eliminarArchivosFotosIncidencia(nombresFotos);
    throw error;
  }
};

const LIMITE_MAX_INCIDENCIAS = 100;
const LIMITE_DEFAULT_INCIDENCIAS = 20;

export const listarIncidencias = async (filtros: DatosListarIncidencias) => {
  const limite = limitarPagina(filtros.limite, LIMITE_DEFAULT_INCIDENCIAS, LIMITE_MAX_INCIDENCIAS);
  validarCursor(filtros.cursor);
  const where = await construirWhereIncidencias(filtros);

  const incidencias = await incidenciaRepositorio.listar({
    where,
    take: limite + 1,
    cursor: filtros.cursor
  });

  const hayMas = incidencias.length > limite;
  const items = hayMas ? incidencias.slice(0, limite) : incidencias;
  const nextCursor = hayMas ? items[items.length - 1].id : null;

  return {
    incidencias: items.map((item) =>
      mapearIncidencia(item, { usuarioId: filtros.usuarioId, rol: filtros.rol })
    ),
    nextCursor
  };
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
