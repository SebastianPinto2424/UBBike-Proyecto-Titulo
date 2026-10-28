import { ErrorHttp } from '../../../comun/errores/error-http';
import { EstadoMovimiento } from '../../historial/estado-movimiento';
import { TipoMovimiento } from '../../historial/tipo-movimiento';
import { EstadoQr } from '../../qr/estado-qr';
import { notificarEstadoQr, obtenerCodigoQrEscaneadoParaMovimiento } from '../../qr/qr.servicio';
import { mapearMovimiento } from './acceso.mapeador';
import * as accesoRepositorio from './acceso.repositorio';
import { validarBicicleteroDelRetiro, validarReglaMovimiento } from './acceso.reglas';
import {
  obtenerBicicleteroOperacion,
  registrarMovimiento,
  notificarMovimiento
} from './registro-movimiento.servicio';

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

const notificarResultadoQr = (
  movimientoCompleto: Awaited<ReturnType<typeof accesoRepositorio.buscarMovimientoCompleto>>,
  qrId: string
) =>
  notificarEstadoQr(movimientoCompleto.usuario.id, {
    qrId,
    estado:
      movimientoCompleto.estado === EstadoMovimiento.CONFIRMADO
        ? EstadoQr.CONFIRMADO
        : EstadoQr.DENEGADO,
    tipo: movimientoCompleto.tipo,
    motivo: movimientoCompleto.motivoDenegacion
  });

export const confirmarQr = async (datos: DatosConfirmarQr) => {
  const { movimientoCompleto, qrId } = await accesoRepositorio.ejecutarEnTransaccion(async (db) => {
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

    const movimiento = await registrarMovimiento({
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
    return { movimientoCompleto: movimiento, qrId: codigo.id };
  });

  void notificarMovimiento(movimientoCompleto);
  notificarResultadoQr(movimientoCompleto, qrId);
  return mapearMovimiento(movimientoCompleto);
};

export const denegarQr = async (datos: DatosDenegarQr) => {
  const { movimientoCompleto, qrId } = await accesoRepositorio.ejecutarEnTransaccion(async (db) => {
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

    const movimiento = await registrarMovimiento({
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
    return { movimientoCompleto: movimiento, qrId: codigo.id };
  });

  void notificarMovimiento(movimientoCompleto);
  notificarResultadoQr(movimientoCompleto, qrId);
  return mapearMovimiento(movimientoCompleto);
};
