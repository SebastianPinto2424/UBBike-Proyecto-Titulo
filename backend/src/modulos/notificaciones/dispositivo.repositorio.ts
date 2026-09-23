import { prisma } from '../../configuracion/prisma';

export const guardarToken = (usuarioId: string, token: string, plataforma: string) =>
  prisma.dispositivoToken.upsert({
    where: { token },
    create: { usuarioId, token, plataforma },
    update: { usuarioId, plataforma }
  });

export const eliminarToken = (usuarioId: string, token: string) =>
  prisma.dispositivoToken.deleteMany({ where: { token, usuarioId } });

export const eliminarTokens = (tokens: string[]) =>
  prisma.dispositivoToken.deleteMany({ where: { token: { in: tokens } } });

export const listarTokensDeUsuario = async (usuarioId: string): Promise<string[]> => {
  const filas = await prisma.dispositivoToken.findMany({
    where: { usuarioId },
    select: { token: true }
  });

  return filas.map((fila) => fila.token);
};
