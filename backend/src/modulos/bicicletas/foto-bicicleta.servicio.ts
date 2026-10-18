import { eliminarArchivoFoto, FotoGuardada, guardarFoto } from '../../comun/archivos/foto.servicio';

export type FotoBicicletaGuardada = FotoGuardada;

const carpetaBicicletas = 'bicicletas';

export const guardarFotoBicicleta = async (
  bicicletaId: string,
  fotoDataUrl: string
): Promise<FotoBicicletaGuardada> => guardarFoto(carpetaBicicletas, bicicletaId, fotoDataUrl);

export const eliminarArchivoFotoBicicleta = async (nombreArchivo?: string | null) =>
  eliminarArchivoFoto(carpetaBicicletas, nombreArchivo);
