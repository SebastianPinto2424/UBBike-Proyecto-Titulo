import path from 'node:path';
import { existsSync } from 'node:fs';
import { ErrorHttp } from '../../../comun/errores/error-http';
import { entorno } from '../../../configuracion/entorno';
import type { ClientePrisma } from '../../../configuracion/prisma';
import { Prisma } from '../../../generated/prisma/client';
import { registrarAuditoria } from '../../auditoria/auditoria.servicio';
import { crearCorreoMovimiento } from '../../correos/operacion.plantillas';
import { enviarCorreo } from '../../correos/correo.servicio';
import { EstadoMovimiento } from '../../historial/estado-movimiento';
import { TipoMovimiento } from '../../historial/tipo-movimiento';
import { RolUsuario } from '../../usuarios/rol-usuario';
import {
  EventosTiempoReal,
  emitirATodos,
  emitirTiempoReal,
  salaRol,
  salaUsuario
} from '../../../tiempo-real/tiempo-real';
import * as accesoRepositorio from './acceso.repositorio';
import { impedirAutovalidacion } from './acceso.reglas';

type UsuarioOperacion = Prisma.UsuarioGetPayload<Record<string, never>>;
type BicicleteroOperacion = Prisma.BicicleteroGetPayload<Record<string, never>>;
type BicicletaOperacion = Prisma.BicicletaGetPayload<{
  include: {
    bicicleteroActual: true;
  };
}>;

export const obtenerBicicleteroOperacion = async (
  guardiaId: string,
  rol: string,
  bicicleteroId?: string,
  bicicleteroQr?: BicicleteroOperacion | null,
  db?: ClientePrisma
): Promise<BicicleteroOperacion> => {
  const validarAsignacionGuardia = async (bicicletero: BicicleteroOperacion) => {
    if (!bicicletero.activo) throw new ErrorHttp(409, 'El bicicletero está inactivo');
    if (rol !== RolUsuario.GUARDIA) {
      return;
    }

    const asignacion = await accesoRepositorio.buscarAsignacionActiva(
      guardiaId,
      bicicletero.id,
      db
    );

    if (!asignacion) {
      throw new ErrorHttp(403, 'El guardia no está asignado a este bicicletero');
    }
  };

  if (bicicleteroId) {
    const bicicletero = await accesoRepositorio.buscarBicicletero(bicicleteroId, db);

    if (!bicicletero) {
      throw new ErrorHttp(404, 'Bicicletero no encontrado');
    }

    await validarAsignacionGuardia(bicicletero);
    return bicicletero;
  }

  if (bicicleteroQr) {
    return obtenerBicicleteroOperacion(guardiaId, rol, bicicleteroQr.id, null, db);
  }

  const asignacion = await accesoRepositorio.buscarAsignacionActivaConBicicletero(guardiaId, db);

  if (!asignacion) {
    throw new ErrorHttp(400, 'Debes indicar bicicletero para esta operación');
  }

  return obtenerBicicleteroOperacion(guardiaId, rol, asignacion.bicicletero.id, null, db);
};

export const registrarMovimiento = async ({
  usuario,
  bicicleta,
  bicicletero,
  guardiaId,
  tipo,
  estado,
  origen,
  motivo,
  comentario,
  db
}: {
  usuario: UsuarioOperacion;
  bicicleta: BicicletaOperacion;
  bicicletero: BicicleteroOperacion;
  guardiaId: string;
  tipo: TipoMovimiento;
  estado: EstadoMovimiento;
  origen: 'QR' | 'MANUAL';
  motivo?: string | null;
  comentario?: string | null;
  db: ClientePrisma;
}) => {
  impedirAutovalidacion(usuario.id, guardiaId);
  const comentarioGuardia = comentario?.trim() || null;
  const movimiento = await accesoRepositorio.crearMovimiento(
    {
      usuarioId: usuario.id,
      bicicletaId: bicicleta.id,
      bicicleteroId: bicicletero.id,
      validadoPorGuardiaId: guardiaId,
      tipo,
      estado,
      origen,
      motivoDenegacion: motivo ?? null,
      comentarioGuardia
    },
    db
  );

  if (estado === EstadoMovimiento.CONFIRMADO) {
    if (
      tipo === TipoMovimiento.INGRESO &&
      (await accesoRepositorio.contarOcupacion(bicicletero.id, db)) >= bicicletero.capacidad
    ) {
      throw new ErrorHttp(409, 'El bicicletero no tiene cupos disponibles');
    }
    const cambio = await accesoRepositorio.moverBicicletaSiCoincide(
      bicicleta.id,
      bicicleta.dentroBicicletero,
      bicicleta.bicicleteroActualId,
      tipo === TipoMovimiento.INGRESO
        ? {
            dentroBicicletero: true,
            bicicleteroActualId: bicicletero.id
          }
        : {
            dentroBicicletero: false,
            bicicleteroActualId: null
          },
      db
    );
    if (cambio.count !== 1)
      throw new ErrorHttp(409, 'La bicicleta cambió de estado; vuelve a consultar');
  }

  await registrarAuditoria(
    {
      actorUsuarioId: guardiaId,
      accion:
        estado === EstadoMovimiento.CONFIRMADO ? 'MOVIMIENTO_CONFIRMADO' : 'MOVIMIENTO_DENEGADO',
      entidad: 'movimientos',
      entidadId: movimiento.id,
      datos: {
        usuarioId: usuario.id,
        bicicletaId: bicicleta.id,
        bicicleteroId: bicicletero.id,
        tipo,
        estado,
        origen,
        comentarioGuardia
      }
    },
    db
  );

  const completo = await accesoRepositorio.buscarMovimientoCompleto(movimiento.id, db);
  await prepararCorreoMovimiento(completo, db);
  return completo;
};

export const notificarMovimiento = (
  movimientoCompleto: Awaited<ReturnType<typeof accesoRepositorio.buscarMovimientoCompleto>>
) => {
  emitirTiempoReal(
    [
      salaUsuario(movimientoCompleto.usuario.id),
      salaRol(RolUsuario.GUARDIA),
      salaRol(RolUsuario.ADMIN_CENTRAL),
      salaRol(RolUsuario.ADMINISTRADOR)
    ],
    EventosTiempoReal.MOVIMIENTO
  );
  if (movimientoCompleto.estado === EstadoMovimiento.CONFIRMADO) {
    emitirATodos(EventosTiempoReal.BICICLETEROS);
  }
};

const prepararCorreoMovimiento = async (
  movimientoCompleto: Awaited<ReturnType<typeof accesoRepositorio.buscarMovimientoCompleto>>,
  db: ClientePrisma
) => {
  const fotoNombreArchivo = movimientoCompleto.bicicleta.fotoNombreArchivo;
  const rutaFoto = fotoNombreArchivo
    ? path.join(entorno.archivos.directorioUploads, 'bicicletas', fotoNombreArchivo)
    : null;
  const hayFoto = rutaFoto != null && existsSync(rutaFoto);
  const fotoCid = hayFoto ? `foto-bicicleta-${movimientoCompleto.id}@ubbike` : null;

  const correo = crearCorreoMovimiento({
    nombre: movimientoCompleto.usuario.nombre,
    tipo: movimientoCompleto.tipo,
    estado: movimientoCompleto.estado,
    origen: movimientoCompleto.origen,
    bicicleta: movimientoCompleto.bicicleta.descripcion,
    marca: movimientoCompleto.bicicleta.marca,
    modelo: movimientoCompleto.bicicleta.modelo,
    color: movimientoCompleto.bicicleta.color,
    aro: movimientoCompleto.bicicleta.aro,
    numeroSerie: movimientoCompleto.bicicleta.numeroSerie,
    bicicletero: movimientoCompleto.bicicletero.nombre,
    guardia: movimientoCompleto.validadoPorGuardia.nombre,
    fecha: movimientoCompleto.creadoEn,
    motivoDenegacion: movimientoCompleto.motivoDenegacion,
    comentarioGuardia: movimientoCompleto.comentarioGuardia,
    fotoCid
  });

  await enviarCorreo(
    {
      para: movimientoCompleto.usuario.correo,
      asunto: correo.asunto,
      texto: correo.texto,
      html: correo.html,
      referencia: movimientoCompleto.id,
      adjuntos:
        hayFoto && fotoNombreArchivo && rutaFoto
          ? [{ filename: fotoNombreArchivo, path: rutaFoto, cid: fotoCid! }]
          : undefined
    },
    db
  );
};
