import nodemailer from 'nodemailer';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import type { ClientePrisma } from '../../configuracion/prisma';
import { encolarEntrega } from '../entregas/entrega.repositorio';
import { entorno } from '../../configuracion/entorno';

type AdjuntoCorreo = {
  filename: string;
  path: string;
  cid?: string;
};

export type DatosCorreo = {
  para: string;
  asunto: string;
  texto: string;
  html: string;
  adjuntos?: AdjuntoCorreo[];
  referencia?: string;
};

export type CorreoEncolado = Omit<DatosCorreo, 'adjuntos'> & {
  adjuntos?: Array<{ filename: string; content: string; encoding: string; cid?: string }>;
};

const crearTransporte = () => {
  if (!entorno.correo.host) {
    return null;
  }

  const auth =
    entorno.correo.usuario && entorno.correo.contrasena
      ? {
          user: entorno.correo.usuario,
          pass: entorno.correo.contrasena
        }
      : undefined;

  return nodemailer.createTransport({
    host: entorno.correo.host,
    port: entorno.correo.puerto,
    secure: entorno.correo.seguro,
    auth,
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 30000,
    disableUrlAccess: true
  });
};

export const enviarCorreo = async (datos: DatosCorreo, db?: ClientePrisma): Promise<void> => {
  const adjuntos = datos.adjuntos
    ? await Promise.all(
        datos.adjuntos.map(async (adjunto) => ({
          filename: adjunto.filename,
          cid: adjunto.cid,
          content: (await readFile(adjunto.path)).toString('base64'),
          encoding: 'base64'
        }))
      )
    : undefined;
  await encolarEntrega('CORREO', { ...datos, adjuntos }, db);
};

export const entregarCorreo = async (datos: CorreoEncolado, entregaId: string): Promise<void> => {
  const transporte = crearTransporte();

  if (!transporte) {
    if (entorno.ambiente === 'production') {
      throw new Error('SMTP_HOST debe estar configurado para enviar correos en produccion');
    }

    console.log('[correo-desarrollo]', {
      entregaId,
      aviso: 'SMTP no configurado; entrega simulada sin registrar enlaces ni datos personales'
    });
    return;
  }

  await transporte.sendMail({
    messageId: `<${entregaId}@ubbike.local>`,
    from: entorno.correo.remitente,
    replyTo: entorno.correo.soporte,
    to: datos.para,
    subject: datos.asunto,
    text: datos.texto,
    html: datos.html,
    attachments: datos.adjuntos,
    headers: { 'X-Entity-Ref-ID': datos.referencia ?? randomUUID() }
  });
};
