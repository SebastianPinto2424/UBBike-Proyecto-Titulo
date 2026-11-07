import crypto from 'crypto';
import jwt, { SignOptions } from 'jsonwebtoken';
import { ErrorHttp } from '../../comun/errores/error-http';
import { entorno } from '../../configuracion/entorno';
import { obtenerClienteRedis } from '../../configuracion/redis';
import { RolUsuario } from '../usuarios/rol-usuario';

export const horasExpiracionVerificacionCorreo = 24;

export const crearTokenSeguro = (): string => crypto.randomBytes(32).toString('hex');

export const hashearToken = (token: string): string =>
  crypto.createHash('sha256').update(token).digest('hex');

export const crearTokenSesion = (
  usuarioId: string,
  rol: RolUsuario,
  versionSesion: number
): string => {
  const opcionesFirma: SignOptions = {
    expiresIn: entorno.jwt.expiracion as SignOptions['expiresIn'],
    issuer: entorno.jwt.emisor,
    audience: entorno.jwt.audiencia
  };

  return jwt.sign({ usuarioId, rol, versionSesion }, entorno.jwt.secreto, opcionesFirma);
};

export const resolverRolRegistrable = (correo: string): RolUsuario => {
  if (correo.endsWith('@alumnos.ubiobio.cl')) {
    return RolUsuario.ESTUDIANTE;
  }

  if (correo.endsWith('@ubiobio.cl')) {
    return RolUsuario.FUNCIONARIO;
  }

  throw new ErrorHttp(400, 'Debes usar un correo institucional UBB válido');
};

const claveTokenRenovacion = (usuarioId: string, tokenHash: string) =>
  `refresh:${usuarioId}:${tokenHash}`;

export const crearTokenRenovacion = (): string => crypto.randomBytes(48).toString('base64url');

export const guardarTokenRenovacion = async (
  usuarioId: string,
  token: string,
  versionSesion = 0
): Promise<void> => {
  const redis = await obtenerClienteRedis();

  if (!redis) {
    return;
  }

  const hash = hashearToken(token);
  const clave = claveTokenRenovacion(usuarioId, hash);
  const ttlSegundos = entorno.jwt.expiracionRenovacionDias * 24 * 60 * 60;

  await redis.set(clave, `v:${versionSesion}`, { EX: ttlSegundos });
};

export const rotarTokenRenovacion = async (
  usuarioId: string,
  anterior: string,
  siguiente: string,
  versionSesion: number
): Promise<boolean> => {
  const redis = await obtenerClienteRedis();
  if (!redis) throw new ErrorHttp(503, 'Servicio de sesión no disponible. Intenta nuevamente.');
  const resultado = await redis.eval(
    `
    if redis.call('GET', KEYS[1]) ~= ARGV[1] then return 0 end
    redis.call('DEL', KEYS[1])
    redis.call('SET', KEYS[2], ARGV[1], 'EX', ARGV[2])
    return 1
  `,
    {
      keys: [
        claveTokenRenovacion(usuarioId, hashearToken(anterior)),
        claveTokenRenovacion(usuarioId, hashearToken(siguiente))
      ],
      arguments: [`v:${versionSesion}`, String(entorno.jwt.expiracionRenovacionDias * 86400)]
    }
  );
  return resultado === 1;
};

export const revocarTokenRenovacion = async (usuarioId: string, token: string): Promise<void> => {
  const redis = await obtenerClienteRedis();

  if (!redis) {
    return;
  }

  const hash = hashearToken(token);
  const clave = claveTokenRenovacion(usuarioId, hash);
  await redis.del(clave);
};

export const revocarTodosLosTokensRenovacion = async (usuarioId: string): Promise<void> => {
  const redis = await obtenerClienteRedis();

  if (!redis) {
    return;
  }

  const patron = `refresh:${usuarioId}:*`;
  let cursor = '0';

  do {
    const resultado = await redis.scan(cursor, { MATCH: patron, COUNT: 100 });
    cursor = String(resultado.cursor);

    if (resultado.keys.length > 0) {
      await redis.del(resultado.keys);
    }
  } while (cursor !== '0');
};
