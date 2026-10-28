import type { ValidationError } from 'joi';
import { ErrorHttp } from '../../comun/errores/error-http';
import { cambiarContrasena } from '../autenticacion/contrasena.servicio';
import {
  completarRegistro,
  reenviarVerificacionConEnlace,
  verificarCorreo
} from '../autenticacion/registro.servicio';
import {
  mensajeVerificacionUsada,
  revisarEnlaceCuenta,
  type RevisionEnlaceCuenta
} from '../autenticacion/enlace-cuenta.servicio';
import type { AccionEnlace, ResultadoEnlace } from './enlace.servicio';
import { esquemaFormularioContrasena, esquemaFormularioRegistro } from './enlace.validacion';

const camposFormulario = ['nombre', 'contrasena', 'confirmacion'] as const;

type CampoFormulario = (typeof camposFormulario)[number];

export type ErroresFormulario = Partial<Record<CampoFormulario, string>>;

export type EnlaceValido = Extract<RevisionEnlaceCuenta, { valido: true }>;

export type ProcesoEnlace =
  | { tipo: 'listo'; resultado: ResultadoEnlace }
  | {
      tipo: 'formulario';
      token: string;
      enlace: EnlaceValido;
      errores: ErroresFormulario;
      nombre?: string;
    }
  | {
      tipo: 'error';
      estado: number;
      titulo: string;
      mensaje: string;
      reenviarToken?: string;
    };

const formatoToken = /^[a-f0-9]{64}$/;

const enlaceIncompleto: RevisionEnlaceCuenta = {
  valido: false,
  titulo: 'Enlace no válido',
  mensaje:
    'Este enlace no es válido o está incompleto. Vuelve a abrir el correo o solicita uno nuevo desde la app.'
};

export const revisarEnlace = async (
  accion: AccionEnlace,
  token: string
): Promise<RevisionEnlaceCuenta> =>
  formatoToken.test(token) ? revisarEnlaceCuenta(accion, token) : enlaceIncompleto;

const leerErrores = (error: ValidationError): ErroresFormulario => {
  const errores: ErroresFormulario = {};
  for (const detalle of error.details) {
    const campo = detalle.path[0];
    if (
      typeof campo === 'string' &&
      (camposFormulario as readonly string[]).includes(campo) &&
      !errores[campo as CampoFormulario]
    ) {
      errores[campo as CampoFormulario] = detalle.message;
    }
  }
  return errores;
};

const texto = (valor: unknown) => (typeof valor === 'string' ? valor : '');

export const procesarEnlace = async (
  accion: AccionEnlace,
  cuerpo: Record<string, unknown>
): Promise<ProcesoEnlace> => {
  const token = texto(cuerpo.token);
  const revision = await revisarEnlace(accion, token);

  if (!revision.valido) {
    return {
      tipo: 'error',
      estado: 400,
      titulo: revision.titulo,
      mensaje: revision.mensaje,
      ...(revision.reenviable ? { reenviarToken: token } : {})
    };
  }

  try {
    if (accion === 'verificar-correo') {
      await verificarCorreo(token);
      return { tipo: 'listo', resultado: 'correo-verificado' };
    }

    const esquema =
      accion === 'completar-registro' ? esquemaFormularioRegistro : esquemaFormularioContrasena;
    const { error, value } = esquema.validate(cuerpo, {
      abortEarly: false,
      allowUnknown: true
    });

    if (error) {
      return {
        tipo: 'formulario',
        token,
        enlace: revision,
        errores: leerErrores(error),
        nombre: texto(cuerpo.nombre)
      };
    }

    if (accion === 'completar-registro') {
      await completarRegistro({ token, nombre: value.nombre, contrasena: value.contrasena });
      return { tipo: 'listo', resultado: 'registro-completado' };
    }

    const resultado = await cambiarContrasena(token, value.contrasena);
    return {
      tipo: 'listo',
      resultado: resultado.activacion ? 'cuenta-activada' : 'contrasena-actualizada'
    };
  } catch (error) {
    if (error instanceof ErrorHttp) {
      return {
        tipo: 'error',
        estado: error.statusCode,
        titulo: 'No se pudo completar',
        mensaje: error.message
      };
    }
    throw error;
  }
};

export const reenviarConEnlace = async (token: string): Promise<ProcesoEnlace> => {
  const enviado = formatoToken.test(token) && (await reenviarVerificacionConEnlace(token));
  return enviado
    ? { tipo: 'listo', resultado: 'enlace-reenviado' }
    : { tipo: 'error', estado: 400, titulo: 'Enlace no válido', mensaje: mensajeVerificacionUsada };
};
