import { randomUUID } from 'crypto';
import { ErrorHttp } from '../../comun/errores/error-http';
import { limitarPagina, validarCursor } from '../../comun/utilidades/paginacion';
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
import { crearCorreoIncidenciaNueva } from '../correos/operacion.plantillas';
import { enviarCorreo } from '../correos/correo.servicio';
import { EventosTiempoReal, emitirTiempoReal, salaRol } from '../../tiempo-real/tiempo-real';
import { EstadoIncidencia } from './estado-incidencia';
import * as incidenciaRepositorio from './incidencia.repositorio';
import type { IncidenciaCompleta } from './incidencia.repositorio';
import {
  eliminarArchivosFotosIncidencia,
  guardarFotosIncidencia
} from './foto-incidencia.servicio';
import { TipoIncidencia } from './tipo-incidencia';
import { rolesCentral, estadosCerradosIncidencia } from './incidencia.reglas';
import { etiquetaTipoIncidencia, mapearIncidencia } from './incidencia.mapeador';

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

export const enviarCorreosCentralIncidencia = async (
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
