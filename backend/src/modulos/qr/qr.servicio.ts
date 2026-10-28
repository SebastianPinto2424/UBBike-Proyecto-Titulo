import crypto from 'crypto';
import { bloquearClave } from '../../comun/utilidades/bloqueos';
import { ErrorHttp } from '../../comun/errores/error-http';
import { entorno } from '../../configuracion/entorno';
import type { ClientePrisma } from '../../configuracion/prisma';
import type {
  Bicicleta,
  Bicicletero,
  CodigoQrTemporal,
  Usuario
} from '../../generated/prisma/client';
import { EventosTiempoReal, emitirTiempoReal, salaUsuario } from '../../tiempo-real/tiempo-real';
import { TipoMovimiento } from '../historial/tipo-movimiento';
import { RolUsuario } from '../usuarios/rol-usuario';
import { EstadoQr } from './estado-qr';
import * as qrRepositorio from './qr.repositorio';

const duracionQrSegundos = entorno.qr.duracionSegundos;

type DatosGenerarQr = {
  usuarioId: string;
  bicicletaId?: string;
  bicicleteroId?: string;
  tipo?: TipoMovimiento;
};

type ContextoValidacionQr = {
  validadorUsuarioId: string;
  rol: string;
};

type BicicletaConBicicleteroActual = Bicicleta & {
  bicicleteroActual: Bicicletero | null;
};

type CodigoQrCompleto = CodigoQrTemporal & {
  usuario: Usuario;
  bicicleta: BicicletaConBicicleteroActual;
  bicicletero: Bicicletero | null;
};

type EventoEstadoQr = {
  qrId: string;
  estado: EstadoQr;
  tipo: string;
  motivo?: string | null;
};

export const notificarEstadoQr = (usuarioId: string, evento: EventoEstadoQr) =>
  emitirTiempoReal([salaUsuario(usuarioId)], EventosTiempoReal.QR, evento);

const buscarBicicletaParaQr = async (usuarioId: string, bicicletaId?: string) => {
  const bicicleta = await qrRepositorio.buscarBicicletaParaQr(usuarioId, bicicletaId);

  if (!bicicleta) {
    throw new ErrorHttp(
      404,
      bicicletaId ? 'Bicicleta no encontrada' : 'Debes activar una bicicleta antes de generar el QR'
    );
  }

  return bicicleta;
};

export const generarQrTemporal = async (datos: DatosGenerarQr) => {
  const bicicleta = await buscarBicicletaParaQr(datos.usuarioId, datos.bicicletaId);
  const tipo =
    datos.tipo ?? (bicicleta.dentroBicicletero ? TipoMovimiento.RETIRO : TipoMovimiento.INGRESO);
  const bicicletero = datos.bicicleteroId
    ? await qrRepositorio.buscarBicicletero(datos.bicicleteroId)
    : bicicleta.bicicleteroActual;

  if (datos.bicicleteroId && !bicicletero) {
    throw new ErrorHttp(404, 'Bicicletero no encontrado');
  }

  if (tipo === TipoMovimiento.INGRESO && !bicicletero) {
    throw new ErrorHttp(400, 'Selecciona un bicicletero para generar QR de ingreso');
  }
  if (bicicletero && !bicicletero.activo) throw new ErrorHttp(409, 'El bicicletero está inactivo');

  if (tipo === TipoMovimiento.RETIRO && !bicicleta.dentroBicicletero) {
    throw new ErrorHttp(409, 'La bicicleta no registra ingreso activo');
  }

  if (
    tipo === TipoMovimiento.RETIRO &&
    bicicleta.bicicleteroActualId &&
    bicicletero?.id !== bicicleta.bicicleteroActualId
  ) {
    throw new ErrorHttp(
      409,
      'La bicicleta está registrada en otro bicicletero. El retiro debe hacerse donde ingresó.'
    );
  }

  if (tipo === TipoMovimiento.INGRESO && bicicleta.dentroBicicletero) {
    throw new ErrorHttp(409, 'La bicicleta ya registra ingreso activo');
  }

  const token = `UBBIKE-${crypto.randomBytes(24).toString('base64url')}`;
  const expiraEn = new Date(Date.now() + duracionQrSegundos * 1000);
  const codigo = await qrRepositorio.ejecutarEnTransaccion(async (tx) => {
    await bloquearClave(tx, `qr:${datos.usuarioId}`);
    await qrRepositorio.invalidarQrActivos(datos.usuarioId, tx);

    return qrRepositorio.crearQr(
      {
        token,
        usuarioId: datos.usuarioId,
        bicicletaId: bicicleta.id,
        bicicleteroId: bicicletero?.id ?? null,
        tipo,
        expiraEn,
        usado: false
      },
      tx
    );
  });

  return {
    id: codigo.id,
    token: codigo.token,
    tipo: codigo.tipo,
    duracionSegundos: duracionQrSegundos,
    expiraEn: codigo.expiraEn,
    bicicleta: {
      id: bicicleta.id,
      descripcion: bicicleta.descripcion,
      marca: bicicleta.marca,
      modelo: bicicleta.modelo,
      color: bicicleta.color,
      aro: bicicleta.aro,
      numeroSerie: bicicleta.numeroSerie,
      fotoUrl: bicicleta.fotoUrl
    },
    bicicletero: bicicletero
      ? {
          id: bicicletero.id,
          nombre: bicicletero.nombre
        }
      : null
  };
};

const validarBicicleteroGuardia = async (
  codigo: CodigoQrCompleto,
  contexto?: ContextoValidacionQr
) => {
  if (contexto?.rol !== RolUsuario.GUARDIA) {
    return;
  }

  const bicicleteroQr = codigo.bicicletero ?? codigo.bicicleta.bicicleteroActual;

  if (!bicicleteroQr) {
    throw new ErrorHttp(400, 'El QR no tiene bicicletero asociado');
  }

  const asignacion = await qrRepositorio.buscarAsignacionActiva(
    contexto.validadorUsuarioId,
    bicicleteroQr.id
  );

  if (!asignacion) {
    throw new ErrorHttp(
      403,
      `Este QR es para ${bicicleteroQr.nombre}, que no corresponde a tu turno`
    );
  }
};

export const validarQrTemporal = async (token: string, contexto?: ContextoValidacionQr) => {
  const codigo = await obtenerCodigoQrValido(token);
  await validarBicicleteroGuardia(codigo, contexto);

  if (contexto) {
    const marcado = await qrRepositorio.marcarEscaneadoPorGuardia(
      codigo.id,
      contexto.validadorUsuarioId
    );

    if (marcado.count !== 1) {
      throw new ErrorHttp(409, 'Otro guardia ya está revisando este QR');
    }

    notificarEstadoQr(codigo.usuario.id, {
      qrId: codigo.id,
      estado: EstadoQr.ESCANEADO,
      tipo: codigo.tipo
    });
  }

  return {
    valido: true,
    token: codigo.token,
    tipo: codigo.tipo,
    expiraEn: codigo.expiraEn,
    usuario: {
      id: codigo.usuario.id,
      nombre: codigo.usuario.nombre,
      correo: codigo.usuario.correo,
      rut: codigo.usuario.rut
    },
    bicicleta: {
      id: codigo.bicicleta.id,
      descripcion: codigo.bicicleta.descripcion,
      marca: codigo.bicicleta.marca,
      modelo: codigo.bicicleta.modelo,
      color: codigo.bicicleta.color,
      aro: codigo.bicicleta.aro,
      numeroSerie: codigo.bicicleta.numeroSerie,
      fotoUrl: codigo.bicicleta.fotoUrl
    },
    bicicletero: codigo.bicicletero
      ? {
          id: codigo.bicicletero.id,
          nombre: codigo.bicicletero.nombre
        }
      : null
  };
};

export const consultarEstadoQr = async (qrId: string, usuarioId: string) => {
  const codigo = await qrRepositorio.buscarCodigoDeUsuario(qrId, usuarioId);
  if (!codigo) {
    throw new ErrorHttp(404, 'Este código no es un QR válido de UBBike');
  }

  const base = { qrId: codigo.id, tipo: codigo.tipo };
  if (!codigo.usado) {
    return { ...base, estado: codigo.escaneadoPorGuardiaId ? EstadoQr.ESCANEADO : 'ACTIVO' };
  }

  const movimiento = codigo.escaneadoEn
    ? await qrRepositorio.buscarMovimientoDeQr({ ...codigo, escaneadoEn: codigo.escaneadoEn })
    : null;
  if (!movimiento) {
    return { ...base, estado: 'REEMPLAZADO' };
  }

  return {
    ...base,
    estado: movimiento.estado === 'CONFIRMADO' ? EstadoQr.CONFIRMADO : EstadoQr.DENEGADO,
    motivo: movimiento.motivoDenegacion
  };
};

export const liberarQrTemporal = async (token: string, contexto: ContextoValidacionQr) => {
  const codigo = await qrRepositorio.buscarCodigoCompletoPorToken(token);
  if (!codigo) {
    return;
  }

  const liberado = await qrRepositorio.liberarEscaneoDeGuardia(
    codigo.id,
    contexto.validadorUsuarioId
  );

  if (liberado.count === 1) {
    notificarEstadoQr(codigo.usuario.id, {
      qrId: codigo.id,
      estado: EstadoQr.LIBERADO,
      tipo: codigo.tipo
    });
  }
};

export const obtenerCodigoQrValido = async (
  token: string,
  db?: ClientePrisma
): Promise<CodigoQrCompleto> => {
  const codigo = await qrRepositorio.buscarCodigoCompletoPorToken(token, db);

  if (!codigo) {
    throw new ErrorHttp(404, 'Este código no es un QR válido de UBBike');
  }

  if (codigo.usado) {
    throw new ErrorHttp(409, 'Este QR ya se usó o fue reemplazado por uno más reciente');
  }

  if (codigo.expiraEn.getTime() < Date.now()) {
    throw new ErrorHttp(410, 'Este QR expiró. Pide a la persona que genere uno nuevo');
  }

  return codigo;
};

export const obtenerCodigoQrEscaneadoParaMovimiento = async (
  token: string,
  contexto: ContextoValidacionQr,
  db?: ClientePrisma
): Promise<CodigoQrCompleto> => {
  const codigo = await qrRepositorio.buscarCodigoCompletoPorToken(token, db);

  if (!codigo) {
    throw new ErrorHttp(404, 'Este código no es un QR válido de UBBike');
  }

  if (codigo.usado) {
    throw new ErrorHttp(409, 'Este QR ya se usó o fue reemplazado por uno más reciente');
  }

  if (!codigo.escaneadoPorGuardiaId) {
    throw new ErrorHttp(409, 'Debes validar el QR antes de confirmar o denegar');
  }

  if (codigo.escaneadoPorGuardiaId !== contexto.validadorUsuarioId) {
    throw new ErrorHttp(409, 'Otro guardia ya está revisando este QR');
  }

  await validarBicicleteroGuardia(codigo, contexto);

  return codigo;
};
