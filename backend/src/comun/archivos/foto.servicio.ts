import crypto from 'crypto';
import path from 'path';
import { mkdir, rm, writeFile } from 'fs/promises';
import { ErrorHttp } from '../errores/error-http';
import { entorno } from '../../configuracion/entorno';

export type FotoGuardada = {
  fotoUrl: string;
  fotoNombreArchivo: string;
  fotoMimeType: string;
  fotoTamanoBytes: number;
  fotoActualizadaEn: Date;
};

export const maximoBytesFotoPorDefecto = 5_000_000;

const mimePermitidos: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp'
};

const firmaValida = (mimeType: string, bytes: Buffer) => {
  if (bytes.length < 12) {
    return false;
  }

  if (mimeType === 'image/jpeg' || mimeType === 'image/jpg') {
    return bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  }

  if (mimeType === 'image/png') {
    return bytes
      .subarray(0, 8)
      .equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  }

  if (mimeType === 'image/webp') {
    return (
      bytes.subarray(0, 4).toString('ascii') === 'RIFF' &&
      bytes.subarray(8, 12).toString('ascii') === 'WEBP'
    );
  }

  return false;
};

export const guardarFoto = async (
  carpeta: string,
  prefijo: string,
  fotoDataUrl: string,
  maximoBytes: number = maximoBytesFotoPorDefecto
): Promise<FotoGuardada> => {
  const coincidencia = /^data:(image\/(?:jpeg|jpg|png|webp));base64,([A-Za-z0-9+/=]+)$/i.exec(
    fotoDataUrl.trim()
  );

  if (!coincidencia) {
    throw new ErrorHttp(400, 'La foto debe ser una imagen válida en formato JPG, PNG o WEBP');
  }

  const mimeType = coincidencia[1].toLowerCase();
  const extension = mimePermitidos[mimeType];
  const bytes = Buffer.from(coincidencia[2], 'base64');

  if (!extension || !firmaValida(mimeType, bytes)) {
    throw new ErrorHttp(400, 'El contenido de la foto no coincide con una imagen válida');
  }

  if (bytes.length > maximoBytes) {
    const maximoMb = Math.round(maximoBytes / 1_000_000);
    throw new ErrorHttp(400, `La foto es muy pesada. El máximo permitido es ${maximoMb} MB`);
  }

  const directorio = path.join(entorno.archivos.directorioUploads, carpeta);
  await mkdir(directorio, { recursive: true });

  const nombreArchivo = `${prefijo}-${crypto.randomUUID()}.${extension}`;
  await writeFile(path.join(directorio, nombreArchivo), bytes, { flag: 'wx' });

  return {
    fotoUrl: `${entorno.archivos.rutaPublicaUploads}/${carpeta}/${nombreArchivo}`,
    fotoNombreArchivo: nombreArchivo,
    fotoMimeType: mimeType === 'image/jpg' ? 'image/jpeg' : mimeType,
    fotoTamanoBytes: bytes.length,
    fotoActualizadaEn: new Date()
  };
};

export const eliminarArchivoFoto = async (carpeta: string, nombreArchivo?: string | null) => {
  if (!nombreArchivo) {
    return;
  }

  const ruta = path.join(entorno.archivos.directorioUploads, carpeta, nombreArchivo);
  await rm(ruta, { force: true });
};
