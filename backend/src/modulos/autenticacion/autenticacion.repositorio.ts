import { Prisma } from '../../generated/prisma/client';
import { prisma, type ClientePrisma } from '../../configuracion/prisma';

export const ejecutarEnTransaccion = <T>(callback: (client: ClientePrisma) => Promise<T>) =>
  prisma.$transaction(callback);

export const buscarPorCorreo = (correo: string, client: ClientePrisma = prisma) =>
  client.usuario.findUnique({
    where: { correo }
  });

export const buscarPorRut = (rut: string, client: ClientePrisma = prisma) =>
  client.usuario.findUnique({
    where: { rut }
  });

export const buscarPorId = (id: string, client: ClientePrisma = prisma) =>
  client.usuario.findUnique({
    where: { id }
  });

export const buscarPorTokenVerificacion = (tokenHash: string, client: ClientePrisma = prisma) =>
  client.usuario.findFirst({
    where: {
      tokenVerificacionCorreo: tokenHash
    }
  });

export const buscarRegistroParcialPorToken = (tokenHash: string, client: ClientePrisma = prisma) =>
  client.usuario.findFirst({
    where: {
      tokenVerificacionCorreo: tokenHash,
      registroParcial: true
    }
  });

export const buscarPorTokenCambioContrasena = (tokenHash: string, client: ClientePrisma = prisma) =>
  client.usuario.findFirst({
    where: {
      tokenCambioContrasena: tokenHash
    }
  });

export const crear = (data: Prisma.UsuarioUncheckedCreateInput, client: ClientePrisma = prisma) =>
  client.usuario.create({ data });

export const actualizar = (
  id: string,
  data: Prisma.UsuarioUpdateInput,
  client: ClientePrisma = prisma
) =>
  client.usuario.update({
    where: { id },
    data
  });

export const limpiarTokenVerificacion = (id: string, client: ClientePrisma = prisma) =>
  actualizar(
    id,
    {
      tokenVerificacionCorreo: null,
      tokenVerificacionCorreoExpiraEn: null
    },
    client
  );

export const marcarCorreoVerificado = (id: string, client: ClientePrisma = prisma) =>
  actualizar(
    id,
    {
      correoVerificado: true,
      tokenVerificacionCorreo: null,
      tokenVerificacionCorreoExpiraEn: null
    },
    client
  );

export const completarRegistroParcial = (
  id: string,
  data: Pick<Prisma.UsuarioUpdateInput, 'nombre' | 'contrasenaHash'>,
  client: ClientePrisma = prisma
) =>
  actualizar(
    id,
    {
      ...data,
      correoVerificado: true,
      registroParcial: false,
      tokenVerificacionCorreo: null,
      tokenVerificacionCorreoExpiraEn: null,
      versionSesion: {
        increment: 1
      }
    },
    client
  );

export const guardarTokenCambioContrasena = (
  id: string,
  tokenHash: string,
  expiraEn: Date,
  client: ClientePrisma = prisma
) =>
  actualizar(
    id,
    {
      tokenCambioContrasena: tokenHash,
      tokenCambioContrasenaExpiraEn: expiraEn
    },
    client
  );

export const actualizarContrasena = (
  id: string,
  contrasenaHash: string,
  client: ClientePrisma = prisma
) =>
  actualizar(
    id,
    {
      contrasenaHash,
      correoVerificado: true,
      debeCambiarContrasena: false,
      tokenVerificacionCorreo: null,
      tokenVerificacionCorreoExpiraEn: null,
      tokenCambioContrasena: null,
      tokenCambioContrasenaExpiraEn: null,
      versionSesion: {
        increment: 1
      }
    },
    client
  );
