import { bloquearClave } from '../../../comun/utilidades/bloqueos';
import bcrypt from 'bcryptjs';
import { ErrorHttp } from '../../../comun/errores/error-http';
import { crearEnlaceCorreo } from '../../enlaces/enlace.servicio';
import type { ClientePrisma } from '../../../configuracion/prisma';
import { Prisma } from '../../../generated/prisma/client';
import { crearCorreoCompletarRegistro } from '../../correos/cuenta.plantillas';
import { enviarCorreo } from '../../correos/correo.servicio';
import { EstadoMovimiento } from '../../historial/estado-movimiento';
import { TipoMovimiento } from '../../historial/tipo-movimiento';
import {
  crearTokenSeguro,
  hashearToken,
  horasExpiracionVerificacionCorreo,
  resolverRolRegistrable
} from '../../autenticacion/autenticacion.tokens';
import { guardarFotoBicicleta } from '../../bicicletas/foto-bicicleta.servicio';
import { mapearMovimiento } from './acceso.mapeador';
import * as accesoRepositorio from './acceso.repositorio';
import {
  impedirAutovalidacion,
  validarBicicleteroDelRetiro,
  validarReglaMovimiento
} from './acceso.reglas';
import {
  obtenerBicicleteroOperacion,
  registrarMovimiento,
  notificarMovimiento
} from './registro-movimiento.servicio';

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
  guardiaId: string;
  correo?: string;
  rut?: string;
};

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
  const enlace = crearEnlaceCorreo('completar-registro', token);
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

export const buscarCoincidenciaGestionManual = async (datos: DatosBuscarGestionManual) => {
  const criteriosUsuario = construirCriteriosUsuarioManual(datos);

  if (!criteriosUsuario.length) {
    throw new ErrorHttp(400, 'Debes indicar correo o RUT para buscar coincidencias');
  }

  const usuario = await accesoRepositorio.buscarUsuarioGestionManual(criteriosUsuario);

  if (!usuario) {
    return null;
  }

  impedirAutovalidacion(usuario.id, datos.guardiaId);

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

    if (usuario) {
      impedirAutovalidacion(usuario.id, datos.guardiaId);
    }

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
