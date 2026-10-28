import { type AccionEnlace } from '../enlaces/enlace.servicio';
import { hashearToken, horasExpiracionVerificacionCorreo } from './autenticacion.tokens';
import * as autenticacionRepositorio from './autenticacion.repositorio';

export type RevisionEnlaceCuenta =
  | { valido: true; correo: string; activacion: boolean }
  | { valido: false; titulo: string; mensaje: string; reenviable?: boolean };

const enlaceVigente = (expiraEn: Date | null) =>
  expiraEn !== null && expiraEn.getTime() >= Date.now();

const enlaceNoValido = (mensaje: string): RevisionEnlaceCuenta => ({
  valido: false,
  titulo: 'Enlace no válido',
  mensaje
});

const enlaceVencido = (mensaje: string, reenviable = false): RevisionEnlaceCuenta => ({
  valido: false,
  titulo: 'Enlace vencido',
  mensaje,
  ...(reenviable ? { reenviable } : {})
});

export const mensajeVerificacionUsada =
  'Este enlace ya se usó o no es válido. Si ya confirmaste tu correo, inicia sesión en la app; si no, al iniciar sesión podrás pedir un enlace nuevo.';

const pedirNuevoDesdeApp =
  'Pide uno nuevo desde la app: en el inicio de sesión toca "¿Has olvidado tu contraseña?".';

export const revisarEnlaceCuenta = async (
  accion: AccionEnlace,
  token: string
): Promise<RevisionEnlaceCuenta> => {
  const tokenHash = hashearToken(token);

  if (accion === 'cambiar-contrasena') {
    const usuario = await autenticacionRepositorio.buscarPorTokenCambioContrasena(tokenHash);
    if (!usuario) {
      return enlaceNoValido(`Este enlace ya se usó o no es válido. ${pedirNuevoDesdeApp}`);
    }
    if (!enlaceVigente(usuario.tokenCambioContrasenaExpiraEn)) {
      return enlaceVencido(
        usuario.debeCambiarContrasena
          ? `El enlace para activar tu cuenta venció. ${pedirNuevoDesdeApp}`
          : `El enlace para cambiar tu contraseña venció. ${pedirNuevoDesdeApp}`
      );
    }
    return { valido: true, correo: usuario.correo, activacion: usuario.debeCambiarContrasena };
  }

  if (accion === 'completar-registro') {
    const usuario = await autenticacionRepositorio.buscarRegistroParcialPorToken(tokenHash);
    if (!usuario) {
      return enlaceNoValido('Este enlace de registro ya se usó o no es válido.');
    }
    if (!enlaceVigente(usuario.tokenVerificacionCorreoExpiraEn)) {
      return enlaceVencido(
        'El enlace de registro venció. Pide apoyo a un guardia para recibir uno nuevo.'
      );
    }
    return { valido: true, correo: usuario.correo, activacion: true };
  }

  const usuario = await autenticacionRepositorio.buscarPorTokenVerificacion(tokenHash);
  if (!usuario || usuario.registroParcial) {
    return enlaceNoValido(mensajeVerificacionUsada);
  }
  if (!enlaceVigente(usuario.tokenVerificacionCorreoExpiraEn)) {
    return enlaceVencido(
      `Por seguridad, el enlace para confirmar tu correo dura ${horasExpiracionVerificacionCorreo} horas. Pide uno nuevo y te lo enviaremos a tu correo.`,
      true
    );
  }
  return { valido: true, correo: usuario.correo, activacion: false };
};
