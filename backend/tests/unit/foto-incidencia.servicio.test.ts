import { mkdtemp, readdir, rm } from 'fs/promises';
import { tmpdir } from 'os';
import path from 'path';

const directorioTemporal = path.join(tmpdir(), 'ubbike-fotos-');
let directorioUploads = '';

jest.mock('../../src/configuracion/entorno', () => ({
  entorno: {
    archivos: {
      get directorioUploads() {
        return directorioUploads;
      },
      rutaPublicaUploads: '/uploads'
    }
  }
}));

import { ErrorHttp } from '../../src/comun/errors/error-http';
import {
  eliminarArchivosFotosIncidencia,
  guardarFotosIncidencia,
  maximoFotosIncidencia
} from '../../src/modulos/incidencias/foto-incidencia.servicio';

const pngValido =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

beforeEach(async () => {
  directorioUploads = await mkdtemp(directorioTemporal);
});

afterEach(async () => {
  await rm(directorioUploads, { recursive: true, force: true });
});

describe('guardarFotosIncidencia', () => {
  it('sin fotos no escribe nada', async () => {
    const guardadas = await guardarFotosIncidencia('inc-1', []);

    expect(guardadas).toEqual([]);
    await expect(readdir(directorioUploads)).resolves.toEqual([]);
  });

  it('guarda las fotos validas en la carpeta de incidencias', async () => {
    const guardadas = await guardarFotosIncidencia('inc-1', [pngValido, pngValido]);

    expect(guardadas).toHaveLength(2);
    expect(guardadas[0].fotoUrl).toMatch(/^\/uploads\/incidencias\/inc-1-/);
    expect(guardadas[0].fotoMimeType).toBe('image/png');

    const archivos = await readdir(path.join(directorioUploads, 'incidencias'));
    expect(archivos).toHaveLength(2);
  });

  it('rechaza superar el maximo permitido', async () => {
    const demasiadas = Array.from({ length: maximoFotosIncidencia + 1 }, () => pngValido);

    await expect(guardarFotosIncidencia('inc-1', demasiadas)).rejects.toThrow(ErrorHttp);
  });

  it('rechaza contenido que no es una imagen valida', async () => {
    await expect(guardarFotosIncidencia('inc-1', ['data:image/png;base64,QUJD'])).rejects.toThrow(
      ErrorHttp
    );
  });

  it('no deja archivos huerfanos si una foto posterior falla', async () => {
    await expect(
      guardarFotosIncidencia('inc-1', [pngValido, 'data:text/plain;base64,QUJD'])
    ).rejects.toThrow(ErrorHttp);

    const archivos = await readdir(path.join(directorioUploads, 'incidencias'));
    expect(archivos).toEqual([]);
  });
});

describe('eliminarArchivosFotosIncidencia', () => {
  it('borra los archivos indicados', async () => {
    const guardadas = await guardarFotosIncidencia('inc-2', [pngValido]);

    await eliminarArchivosFotosIncidencia(guardadas.map((foto) => foto.fotoNombreArchivo));

    const archivos = await readdir(path.join(directorioUploads, 'incidencias'));
    expect(archivos).toEqual([]);
  });

  it('ignora nombres inexistentes sin fallar', async () => {
    await expect(eliminarArchivosFotosIncidencia(['no-existe.jpg'])).resolves.toBeUndefined();
  });
});
