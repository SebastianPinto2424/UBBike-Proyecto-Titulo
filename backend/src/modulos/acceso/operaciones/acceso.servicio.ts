import path from 'node:path';
import { bloquearClave } from '../../../comun/utils/bloqueos';
import { existsSync } from 'node:fs';
import bcrypt from 'bcryptjs';
import { ErrorHttp } from '../../../comun/errors/error-http';
import { entorno } from '../../../configuracion/entorno';
import type { ClientePrisma } from '../../../configuracion/prisma';
import { Prisma } from '../../../generated/prisma/client';
import { registrarAuditoria } from '../../auditoria/auditoria.servicio';
import {
  crearCorreoCompletarRegistro,
  crearCorreoMovimiento,
  enviarCorreo
} from '../../correos/correo.servicio';
import { EstadoMovimiento } from '../../historial/estado-movimiento';
import { TipoMovimiento } from '../../historial/tipo-movimiento';
import { obtenerCodigoQrEscaneadoParaMovimiento } from '../../qr/qr.servicio';
import { RolUsuario } from '../../usuarios/rol-usuario';
import {
  EventosTiempoReal,
  emitirTiempoReal,
  salaRol,
  salaUsuario
} from '../../../tiempo-real/tiempo-real';
import {
  crearTokenSeguro,
  hashearToken,
  horasExpiracionVerificacionCorreo,
  resolverRolRegistrable
} from '../../autenticacion/autenticacion.tokens';
import { guardarFotoBicicleta } from '../../bicicletas/foto-bicicleta.servicio';
import { mapearMovimiento } from './acceso.mapeador';
import * as accesoRepositorio from './acceso.repositorio';
import { validarBicicleteroDelRetiro, validarReglaMovimiento } from './acceso.reglas';

type DatosConfirmarQr = {
  token: string;
  guardiaId: string;
  rol: string;
  bicicleteroId?: string;
  comentario?: string | null;
};

type DatosDenegarQr = DatosConfirmarQr & {
  motivo: string;
};

type DatosGestionManual = {
  guardiaId: string;
  rol: string;
  nombre?: string;
  correo?: string;
  rut?: string;
  bicicletaId?: string;
  bicicletaDescripcion?: string;
  bicicletaMarca?: string | null;
  bicicletaModelo?: string | null;
  bicicletaColor?: string | null;
  bicicletaAro?: string | null;
  bicicletaNumeroSerie?: string | null;
  bicicletaFotoUrl?: string | null;
  crearBicicletaNueva?: boolean;
  bicicleteroId?: string;
  tipo: TipoMovimiento;
  denegar?: boolean;
  motivo?: string | null;
  comentario?: string | null;
};

type DatosBuscarGestionManual = {
  correo?: string;
  rut?: string;
};

type UsuarioOperacion = Prisma.UsuarioGetPayload<Record<string, never>>;
type BicicleteroOperacion = Prisma.BicicleteroGetPayload<Record<string, never>>;
type BicicletaOperacion = Prisma.BicicletaGetPayload<{
  include: {
    bicicleteroActual: true;
  };
}>;

const limpiarRut = (rut: string) => rut.replace(/\./g, '').replace('-', '').toUpperCase();

const formatearRutConPuntos = (rutLimpio: string) => {
  if (!/^\d{7,8}[0-9K]$/.test(rutLimpio)) {
    return null;
  }

  const cuerpo = rutLimpio.slice(0, -1);
  const dv = rutLimpio.slice(-1);
  const cuerpoFormateado = cuerpo.replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  return `${cuerpoFormateado}-${dv}`;
};

const obtenerVariantesRut = (rut?: string) => {
  const original = rut?.trim();
  if (!original) {
    return [];
  }

  const limpio = limpiarRut(original);
  const sinPuntos = limpio.length > 1 ? `${limpio.slice(0, -1)}-${limpio.slice(-1)}` : limpio;
  const conPuntos = formatearRutConPuntos(limpio);

  return [
    ...new Set([original, original.toUpperCase(), limpio, sinPuntos, conPuntos].filter(Boolean))
  ];
};

const construirCriteriosUsuarioManual = ({ correo, rut }: DatosBuscarGestionManual) => {
  const criterios: Prisma.UsuarioWhereInput[] = [];
  const correoNormalizado = correo?.trim().toLowerCase();

  if (correoNormalizado) {
    criterios.push({ correo: correoNormalizado });
  }

  for (const varianteRut of obtenerVariantesRut(rut)) {
    criterios.push({ rut: varianteRut });
  }

  return criterios;
};

const mapearBicicletaManual = (
  bicicleta: Prisma.BicicletaGetPayload<{ include: { bicicleteroActual: true } }>
) => ({
  id: bicicleta.id,
  descripcion: bicicleta.descripcion,
  marca: bicicleta.marca,
  modelo: bicicleta.modelo,
  color: bicicleta.color,
  aro: bicicleta.aro,
  numeroSerie: bicicleta.numeroSerie,
  fotoUrl: bicicleta.fotoUrl,
  activa: bicicleta.activa,
  dentroBicicletero: bicicleta.dentroBicicletero,
  bicicleteroActual: bicicleta.bicicleteroActual
    ? {
        id: bicicleta.bicicleteroActual.id,
        nombre: bicicleta.bicicleteroActual.nombre,
        ubicacion: bicicleta.bicicleteroActual.ubicacion
      }
    : null
});

const obtenerBicicleteroOperacion = async (
  guardiaId: string,
  rol: string,
  bicicleteroId?: string,
  bicicleteroQr?: BicicleteroOperacion | null,
  db?: ClientePrisma
) => {
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

const registrarMovimiento = async ({
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

const notificarMovimiento = (
  movimientoCompleto: Awaited<ReturnType<typeof accesoRepositorio.buscarMovimientoCompleto>>
) => {
  emitirTiempoReal(
    [
      salaUsuario(movimientoCompleto.usuario.id),
      salaRol(RolUsuario.ADMIN_CENTRAL),
      salaRol(RolUsuario.ADMINISTRADOR)
    ],
    EventosTiempoReal.MOVIMIENTO
  );
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

const crearBicicletaManual = async (
  db: ClientePrisma,
  usuarioId: string,
  datos: DatosGestionManual
) => {
  await bloquearClave(db, `bicicletas:${usuarioId}`);
  const descripcion = datos.bicicletaDescripcion?.trim();
  const marca = datos.bicicletaMarca?.trim();
  const modelo = datos.bicicletaModelo?.trim();
  const color = datos.bicicletaColor?.trim();
  const aro = datos.bicicletaAro?.trim();
  const numeroSerie = datos.bicicletaNumeroSerie?.trim();
  const fotoUrl = datos.bicicletaFotoUrl?.trim();

  if (!descripcion || !marca || !modelo || !color || !aro || !numeroSerie || !fotoUrl) {
    throw new ErrorHttp(
      400,
      'Debes indicar todos los datos y la foto de la bicicleta para el ingreso manual'
    );
  }

  await accesoRepositorio.desactivarBicicletasDeUsuario(usuarioId, db);

  const bicicleta = await accesoRepositorio.crearBicicleta(
    {
      usuarioId,
      descripcion,
      marca,
      modelo,
      color,
      aro,
      numeroSerie,
      activa: true,
      dentroBicicletero: false,
      bicicleteroActualId: null
    },
    db
  );

  const fotoGuardada = await guardarFotoBicicleta(bicicleta.id, fotoUrl);
  await accesoRepositorio.actualizarBicicleta(bicicleta.id, fotoGuardada, db);

  return {
    ...bicicleta,
    ...fotoGuardada
  };
};

const enviarCorreoCompletarRegistro = async (
  correoUsuario: string,
  token: string,
  db: ClientePrisma
) => {
  const enlace = `${entorno.app.urlFrontend}/completar-registro?token=${token}`;
  const correo = crearCorreoCompletarRegistro(correoUsuario, enlace);

  await enviarCorreo(
    {
      para: correoUsuario,
      asunto: correo.asunto,
      texto: correo.texto,
      html: correo.html
    },
    db
  );
};

export const confirmarQr = async (datos: DatosConfirmarQr) => {
  const movimientoCompleto = await accesoRepositorio.ejecutarEnTransaccion(async (db) => {
    const codigo = await obtenerCodigoQrEscaneadoParaMovimiento(
      datos.token,
      {
        validadorUsuarioId: datos.guardiaId,
        rol: datos.rol
      },
      db
    );
    const bicicletero = await obtenerBicicleteroOperacion(
      datos.guardiaId,
      datos.rol,
      datos.bicicleteroId,
      codigo.bicicletero ?? codigo.bicicleta.bicicleteroActual,
      db
    );
    const tipo = codigo.tipo as TipoMovimiento;

    validarReglaMovimiento(codigo.bicicleta, tipo);
    validarBicicleteroDelRetiro(codigo.bicicleta, tipo, bicicletero.id);

    const marcado = await accesoRepositorio.marcarQrUsado(codigo.id, db);

    if (marcado.count !== 1) {
      throw new ErrorHttp(409, 'QR ya fue usado o reemplazado');
    }

    return registrarMovimiento({
      usuario: codigo.usuario,
      bicicleta: codigo.bicicleta,
      bicicletero,
      guardiaId: datos.guardiaId,
      tipo,
      estado: EstadoMovimiento.CONFIRMADO,
      origen: 'QR',
      comentario: datos.comentario,
      db
    });
  });

  void notificarMovimiento(movimientoCompleto);
  return mapearMovimiento(movimientoCompleto);
};

export const denegarQr = async (datos: DatosDenegarQr) => {
  const movimientoCompleto = await accesoRepositorio.ejecutarEnTransaccion(async (db) => {
    const codigo = await obtenerCodigoQrEscaneadoParaMovimiento(
      datos.token,
      {
        validadorUsuarioId: datos.guardiaId,
        rol: datos.rol
      },
      db
    );
    const bicicletero = await obtenerBicicleteroOperacion(
      datos.guardiaId,
      datos.rol,
      datos.bicicleteroId,
      codigo.bicicletero ?? codigo.bicicleta.bicicleteroActual,
      db
    );
    const tipo = codigo.tipo as TipoMovimiento;

    const marcado = await accesoRepositorio.marcarQrUsado(codigo.id, db);

    if (marcado.count !== 1) {
      throw new ErrorHttp(409, 'QR ya fue usado o reemplazado');
    }

    return registrarMovimiento({
      usuario: codigo.usuario,
      bicicleta: codigo.bicicleta,
      bicicletero,
      guardiaId: datos.guardiaId,
      tipo,
      estado: EstadoMovimiento.DENEGADO,
      origen: 'QR',
      motivo: datos.motivo,
      db
    });
  });

  void notificarMovimiento(movimientoCompleto);
  return mapearMovimiento(movimientoCompleto);
};

export const buscarCoincidenciaGestionManual = async (datos: DatosBuscarGestionManual) => {
  const criteriosUsuario = construirCriteriosUsuarioManual(datos);

  if (!criteriosUsuario.length) {
    throw new ErrorHttp(400, 'Debes indicar correo o RUT para buscar coincidencias');
  }

  const usuario = await accesoRepositorio.buscarUsuarioGestionManual(criteriosUsuario);

  if (!usuario) {
    return null;
  }

  return {
    usuario: {
      id: usuario.id,
      nombre: usuario.nombre,
      correo: usuario.correo,
      rut: usuario.rut,
      rol: usuario.rol,
      correoVerificado: usuario.correoVerificado,
      registroParcial: usuario.registroParcial,
      cuentaActiva: usuario.cuentaActiva
    },
    bicicletas: usuario.bicicletas.map(mapearBicicletaManual)
  };
};

export const registrarGestionManual = async (datos: DatosGestionManual) => {
  let tokenCompletarRegistro: string | null = null;
  let correoCompletarRegistro: string | null = null;

  const movimientoCompleto = await accesoRepositorio.ejecutarEnTransaccion(async (db) => {
    const criteriosUsuario = construirCriteriosUsuarioManual(datos);

    if (!criteriosUsuario.length) {
      throw new ErrorHttp(400, 'Debes indicar correo o RUT');
    }

    let usuario = await accesoRepositorio.buscarUsuarioPorCriterios(criteriosUsuario, db);

    if (!usuario) {
      if (!datos.correo || !datos.rut) {
        throw new ErrorHttp(
          400,
          'Para registrar un usuario nuevo debes indicar correo institucional y RUT'
        );
      }

      if (datos.tipo !== TipoMovimiento.INGRESO) {
        throw new ErrorHttp(404, 'Usuario no encontrado para registrar retiro manual');
      }

      const correoNormalizado = datos.correo.toLowerCase();
      const rolAsignado = resolverRolRegistrable(correoNormalizado);
      tokenCompletarRegistro = crearTokenSeguro();
      correoCompletarRegistro = correoNormalizado;

      usuario = await accesoRepositorio.crearUsuario(
        {
          nombre: datos.nombre?.trim() || 'Registro pendiente',
          correo: correoNormalizado,
          rut: datos.rut,
          rol: rolAsignado,
          contrasenaHash: await bcrypt.hash(crearTokenSeguro(), 12),
          cuentaActiva: true,
          correoVerificado: false,
          registroParcial: true,
          tokenVerificacionCorreo: hashearToken(tokenCompletarRegistro),
          tokenVerificacionCorreoExpiraEn: new Date(
            Date.now() + 1000 * 60 * 60 * horasExpiracionVerificacionCorreo
          )
        },
        db
      );
    } else if (usuario.registroParcial) {
      if (datos.tipo === TipoMovimiento.RETIRO) {
        throw new ErrorHttp(
          409,
          'El usuario debe completar su registro (revisa el correo de activación) antes de retirar la bicicleta.'
        );
      }

      tokenCompletarRegistro = crearTokenSeguro();
      correoCompletarRegistro = usuario.correo;

      usuario = await accesoRepositorio.actualizarUsuario(
        usuario.id,
        {
          tokenVerificacionCorreo: hashearToken(tokenCompletarRegistro),
          tokenVerificacionCorreoExpiraEn: new Date(
            Date.now() + 1000 * 60 * 60 * horasExpiracionVerificacionCorreo
          )
        },
        db
      );
    }

    if (datos.crearBicicletaNueva && datos.bicicletaId) {
      throw new ErrorHttp(400, 'No puedes seleccionar y crear una bicicleta al mismo tiempo');
    }

    const criteriosBicicleta = datos.bicicletaId
      ? {
          id: datos.bicicletaId,
          usuarioId: usuario.id,
          eliminadoEn: null
        }
      : {
          usuarioId: usuario.id,
          activa: true,
          eliminadoEn: null
        };

    let bicicleta = datos.crearBicicletaNueva
      ? null
      : await accesoRepositorio.buscarBicicletaParaGestionManual(criteriosBicicleta, db);

    if (!bicicleta) {
      if (datos.tipo !== TipoMovimiento.INGRESO) {
        throw new ErrorHttp(404, 'Bicicleta activa no encontrada para el usuario');
      }

      bicicleta = await crearBicicletaManual(db, usuario.id, datos);
    }

    const bicicletero = await obtenerBicicleteroOperacion(
      datos.guardiaId,
      datos.rol,
      datos.bicicleteroId,
      bicicleta.bicicleteroActual,
      db
    );

    const estado = datos.denegar ? EstadoMovimiento.DENEGADO : EstadoMovimiento.CONFIRMADO;

    if (estado === EstadoMovimiento.CONFIRMADO) {
      validarReglaMovimiento(bicicleta, datos.tipo);
      validarBicicleteroDelRetiro(bicicleta, datos.tipo, bicicletero.id);
    }

    if (tokenCompletarRegistro && correoCompletarRegistro) {
      await enviarCorreoCompletarRegistro(correoCompletarRegistro, tokenCompletarRegistro, db);
    }

    return registrarMovimiento({
      usuario,
      bicicleta,
      bicicletero,
      guardiaId: datos.guardiaId,
      tipo: datos.tipo,
      estado,
      origen: 'MANUAL',
      motivo: datos.motivo,
      comentario: datos.comentario,
      db
    });
  });

  void notificarMovimiento(movimientoCompleto);
  return mapearMovimiento(movimientoCompleto);
};
