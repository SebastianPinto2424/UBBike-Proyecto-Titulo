import { eliminarArchivoFoto, FotoGuardada, guardarFoto } from '../../comun/archivos/foto.servicio';
import { ErrorHttp } from '../../comun/errors/error-http';

export const maximoFotosIncidencia = 3;

const carpetaIncidencias = 'incidencias';
const maximoBytesPorFoto = 2_000_000;

export const maximoLargoFotoIncidencia = Math.ceil((maximoBytesPorFoto * 4) / 3) + 64;

export type FotoIncidenciaGuardada = FotoGuardada;

export const guardarFotosIncidencia = async (
  prefijo: string,
  fotosDataUrl: string[]
): Promise<FotoIncidenciaGuardada[]> => {
  if (fotosDataUrl.length === 0) {
    return [];
  }

  if (fotosDataUrl.length > maximoFotosIncidencia) {
    throw new ErrorHttp(400, `Puedes adjuntar hasta ${maximoFotosIncidencia} fotos por incidencia`);
  }

  const guardadas: FotoIncidenciaGuardada[] = [];

  try {
    for (const fotoDataUrl of fotosDataUrl) {
      guardadas.push(
        await guardarFoto(carpetaIncidencias, prefijo, fotoDataUrl, maximoBytesPorFoto)
      );
    }
  } catch (error) {
    await eliminarArchivosFotosIncidencia(guardadas.map((foto) => foto.fotoNombreArchivo));
    throw error;
  }

  return guardadas;
};

export const eliminarArchivosFotosIncidencia = async (nombresArchivo: string[]) => {
  for (const nombreArchivo of nombresArchivo) {
    await eliminarArchivoFoto(carpetaIncidencias, nombreArchivo);
  }
};
