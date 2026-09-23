import '../helpers/env-setup';

jest.mock('../../src/modulos/historial/historial.servicio', () => ({
  listarMovimientos: jest.fn(),
  listarMovimientosParaExportar: jest.fn(),
  opcionesHistorial: jest.fn(),
  resumenHistorial: jest.fn()
}));

import ExcelJS from 'exceljs';
import { exportarExcel, mimeExcel } from '../../src/modulos/historial/historial.controlador';
import { listarMovimientosParaExportar } from '../../src/modulos/historial/historial.servicio';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';

const COLUMNA = {
  id: 1,
  fechaMovimiento: 5,
  usuarioNombre: 6,
  usuarioRol: 9,
  bicicletaDescripcion: 13,
  bicicletaMarca: 14,
  bicicleteroUbicacion: 23
} as const;

const movimiento = {
  id: 'mov-1',
  tipo: 'INGRESO',
  estado: 'CONFIRMADO',
  origen: 'QR',
  motivoDenegacion: null,
  comentarioGuardia: null,
  creadoEn: new Date('2026-09-01T12:00:00.000Z'),
  usuario: {
    id: 'user-1',
    nombre: 'Ana Perez',
    correo: 'ana@alumnos.ubiobio.cl',
    rut: '11.111.111-1',
    rol: 'ESTUDIANTE',
    correoVerificado: true,
    cuentaActiva: true,
    creadoEn: new Date('2026-03-10T09:00:00.000Z')
  },
  bicicleta: {
    id: 'bici-1',
    descripcion: 'Bicicleta roja aro 26',
    marca: 'Oxford',
    modelo: 'Cuya',
    color: 'Rojo',
    aro: '26',
    numeroSerie: 'SN-12345',
    activa: true,
    dentroBicicletero: true,
    creadoEn: new Date('2026-04-02T15:30:00.000Z')
  },
  bicicletero: {
    id: 'bic-1',
    nombre: 'Bicicletero cercano a la FACE',
    ubicacion: 'Frente a la Facultad de Ciencias Empresariales'
  },
  validadoPorGuardia: {
    id: 'guardia-1',
    nombre: 'Guardia Turno',
    correo: 'guardia@ubiobio.cl',
    rut: '22.222.222-2'
  }
};

const crearRespuesta = () => {
  const cabeceras: Record<string, string> = {};
  let resolverTermino: () => void;
  const terminado = new Promise<void>((resolver) => {
    resolverTermino = resolver;
  });

  return {
    cabeceras,
    terminado,
    adjunto: undefined as string | undefined,
    enviado: undefined as Buffer | undefined,
    header(nombre: string, valor: string) {
      cabeceras[nombre] = valor;
      return this;
    },
    attachment(nombre: string) {
      this.adjunto = nombre;
      return this;
    },
    send(contenido: Buffer) {
      this.enviado = contenido;
      resolverTermino();
      return this;
    },
    status() {
      return this;
    }
  };
};

const cargarLibro = async (contenido: Buffer) => {
  const libro = new ExcelJS.Workbook();
  await libro.xlsx.load(contenido as unknown as Parameters<typeof libro.xlsx.load>[0]);
  return libro;
};

const ejecutarExportacion = async (rol: string) => {
  const req = { usuario: { usuarioId: 'user-1', rol }, query: {} };
  const res = crearRespuesta();
  let rechazo: unknown;
  const siguiente = jest.fn((error: unknown) => {
    rechazo = error;
  });

  exportarExcel(req as never, res as never, siguiente as never);
  await Promise.race([
    res.terminado,
    new Promise<void>((resolver) => setImmediate(resolver)).then(async () => {
      if (!siguiente.mock.calls.length) {
        await res.terminado;
      }
    })
  ]);

  return { res, siguiente, error: rechazo };
};

const encabezados = (hoja: ExcelJS.Worksheet) =>
  (hoja.getRow(1).values as Array<unknown>).slice(1).map((valor) => String(valor));

describe('exportacion del historial', () => {
  beforeEach(() => {
    (listarMovimientosParaExportar as jest.Mock).mockResolvedValue([movimiento]);
  });

  it('responde un xlsx real cuyo contenido coincide con el tipo declarado', async () => {
    const { res, error } = await ejecutarExportacion(RolUsuario.ADMIN_CENTRAL);

    expect(error).toBeUndefined();
    expect(res.cabeceras['Content-Type']).toBe(mimeExcel);
    expect(res.adjunto).toBe('historial-movimientos-ubbike.xlsx');

    const contenido = res.enviado!;
    expect(contenido.subarray(0, 4)).toEqual(Buffer.from([0x50, 0x4b, 0x03, 0x04]));

    const libro = await cargarLibro(contenido);
    const hoja = libro.getWorksheet('Movimientos')!;

    expect(hoja).toBeDefined();
    expect(hoja.rowCount).toBe(2);
    expect(hoja.getRow(1).getCell(COLUMNA.id).value).toBe('ID Movimiento');
    expect(hoja.getRow(2).getCell(COLUMNA.usuarioNombre).value).toBe('Ana Perez');
    expect(hoja.getRow(2).getCell(COLUMNA.fechaMovimiento).value).toBeInstanceOf(Date);
  });

  it('incluye la ficha completa del usuario y de la bicicleta', async () => {
    const { res } = await ejecutarExportacion(RolUsuario.ADMIN_CENTRAL);
    const libro = await cargarLibro(res.enviado!);
    const hoja = libro.getWorksheet('Movimientos')!;
    const fila = hoja.getRow(2);

    expect(fila.getCell(COLUMNA.usuarioRol).value).toBe('ESTUDIANTE');
    expect(fila.getCell(COLUMNA.bicicletaMarca).value).toBe('Oxford');
    expect(fila.getCell(COLUMNA.bicicleteroUbicacion).value).toBe(
      'Frente a la Facultad de Ciencias Empresariales'
    );

    const titulos = encabezados(hoja);
    expect(titulos).toContain('Bicicleta Color');
    expect(titulos).toContain('Bicicleta N Serie');
    expect(titulos).toContain('Cuenta Activa');
    expect(titulos).toContain('Guardia RUT');
  });

  it('nunca expone secretos ni los datos de la foto', async () => {
    const { res } = await ejecutarExportacion(RolUsuario.ADMIN_CENTRAL);
    const libro = await cargarLibro(res.enviado!);
    const titulos = encabezados(libro.getWorksheet('Movimientos')!).join(' ').toLowerCase();

    for (const prohibido of ['contrasena', 'hash', 'token', 'foto']) {
      expect(titulos).not.toContain(prohibido);
    }
  });

  it('no evalua como formula un texto que empieza con signo igual', async () => {
    (listarMovimientosParaExportar as jest.Mock).mockResolvedValue([
      { ...movimiento, bicicleta: { ...movimiento.bicicleta, descripcion: '=1+1' } }
    ]);

    const { res } = await ejecutarExportacion(RolUsuario.ADMINISTRADOR);

    const libro = await cargarLibro(res.enviado!);
    const celda = libro
      .getWorksheet('Movimientos')!
      .getRow(2)
      .getCell(COLUMNA.bicicletaDescripcion);

    expect(celda.value).toBe('=1+1');
    expect(celda.formula).toBeUndefined();
  });

  it('rechaza la exportacion a roles sin permiso', async () => {
    const { siguiente } = await ejecutarExportacion(RolUsuario.GUARDIA);

    expect(siguiente).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 403 })
    );
    expect(listarMovimientosParaExportar).not.toHaveBeenCalled();
  });
});
