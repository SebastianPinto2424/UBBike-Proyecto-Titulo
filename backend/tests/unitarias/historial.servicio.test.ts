import '../apoyo/configurar-entorno';

jest.mock('../../src/modulos/historial/historial.repositorio', () => ({
  buscarMovimientos: jest.fn(),
  contarMovimientos: jest.fn(),
  buscarMovimientosExportacion: jest.fn(),
  agruparPorGuardia: jest.fn(),
  agruparPorBicicletero: jest.fn(),
  buscarNombresUsuarios: jest.fn(),
  buscarNombresBicicleteros: jest.fn(),
  contarPendientesOperativos: jest.fn(),
  listarGuardiasActivos: jest.fn()
}));

jest.mock('../../src/modulos/bicicleteros/bicicletero.servicio', () => ({
  listarBicicleteros: jest.fn()
}));

import * as historialRepositorio from '../../src/modulos/historial/historial.repositorio';
import { listarBicicleteros } from '../../src/modulos/bicicleteros/bicicletero.servicio';
import {
  listarMovimientos,
  listarMovimientosParaExportar,
  opcionesHistorial,
  resumenHistorial
} from '../../src/modulos/historial/historial.servicio';

const repo = historialRepositorio as jest.Mocked<typeof historialRepositorio>;

const movimiento = {
  id: 'm1',
  tipo: 'INGRESO',
  estado: 'CONFIRMADO',
  motivoDenegacion: null,
  comentarioGuardia: null,
  origen: 'QR',
  creadoEn: new Date('2026-10-20T10:00:00Z'),
  usuario: {
    id: 'u1',
    nombre: 'Ana Rojas',
    correo: 'ana@alumnos.ubiobio.cl',
    rut: '11111111-1',
    contrasenaHash: 'x'
  },
  bicicleta: {
    id: 'b1',
    descripcion: 'Urbana',
    marca: 'Oxford',
    modelo: 'Venus',
    color: 'Azul',
    aro: '26',
    numeroSerie: 'SN-1',
    fotoUrl: 'privada'
  },
  bicicletero: { id: 'r1', nombre: 'Biblioteca', capacidad: 20 },
  validadoPorGuardia: { id: 'g1', nombre: 'Pedro Soto', correo: 'guardia@ubiobio.cl', rut: '2-7' }
};

const whereUsado = () => repo.contarMovimientos.mock.calls[0][0] as { AND?: unknown[] };

beforeEach(() => {
  repo.buscarMovimientos.mockResolvedValue([movimiento] as never);
  repo.contarMovimientos.mockResolvedValue(1);
});

describe('listarMovimientos', () => {
  it('un usuario comun solo ve sus propios movimientos', async () => {
    await listarMovimientos({ usuarioId: 'u1', rol: 'ESTUDIANTE', guardiaId: 'g9' });

    expect(whereUsado()).toEqual({ AND: [{ usuarioId: 'u1' }] });
  });

  it('un guardia solo ve lo que el valido', async () => {
    await listarMovimientos({ usuarioId: 'g1', rol: 'GUARDIA' });

    expect(whereUsado()).toEqual({ AND: [{ validadoPorGuardiaId: 'g1' }] });
  });

  it('la central puede filtrar por guardia o ver todo', async () => {
    await listarMovimientos({ usuarioId: 'a1', rol: 'ADMIN_CENTRAL', guardiaId: 'g2' });
    expect(whereUsado()).toEqual({ AND: [{ validadoPorGuardiaId: 'g2' }] });

    repo.contarMovimientos.mockClear();
    await listarMovimientos({ usuarioId: 'a1', rol: 'ADMINISTRADOR' });
    expect(whereUsado()).toEqual({});
  });

  it('el alcance propio limita a guardias y central a sus bicicletas', async () => {
    await listarMovimientos({ usuarioId: 'g1', rol: 'GUARDIA', alcance: 'PROPIO' });
    expect(whereUsado()).toEqual({ AND: [{ usuarioId: 'g1' }] });

    repo.contarMovimientos.mockClear();
    await listarMovimientos({
      usuarioId: 'a1',
      rol: 'ADMIN_CENTRAL',
      guardiaId: 'g2',
      alcance: 'PROPIO'
    });
    expect(whereUsado()).toEqual({ AND: [{ usuarioId: 'a1' }] });
  });

  it('combina busqueda y filtros', async () => {
    await listarMovimientos({
      usuarioId: 'a1',
      rol: 'ADMINISTRADOR',
      q: 'oxford',
      tipo: 'RETIRO',
      estado: 'DENEGADO',
      origen: 'MANUAL',
      bicicleteroId: 'r1'
    });

    const condiciones = whereUsado().AND as Record<string, unknown>[];
    expect(condiciones[0]).toHaveProperty('OR');
    expect((condiciones[0].OR as unknown[]).length).toBe(10);
    expect(condiciones.slice(1)).toEqual([
      { tipo: 'RETIRO' },
      { estado: 'DENEGADO' },
      { origen: 'MANUAL' },
      { bicicleteroId: 'r1' }
    ]);
  });

  it('ignora los filtros TODOS', async () => {
    await listarMovimientos({
      usuarioId: 'a1',
      rol: 'ADMINISTRADOR',
      tipo: 'TODOS',
      estado: 'TODOS',
      origen: 'TODOS'
    });

    expect(whereUsado()).toEqual({});
  });

  it('una fecha simple en hasta incluye el dia completo', async () => {
    await listarMovimientos({
      usuarioId: 'a1',
      rol: 'ADMINISTRADOR',
      desde: '2026-10-01',
      hasta: '2026-10-31'
    });

    const [{ creadoEn }] = whereUsado().AND as { creadoEn: { gte: Date; lte: Date } }[];
    expect(creadoEn.gte.getHours()).toBe(0);
    expect(creadoEn.lte.getHours()).toBe(23);
    expect(creadoEn.lte.getMinutes()).toBe(59);
    expect(creadoEn.lte.getDate()).toBe(31);
  });

  it.each(['DIA', 'SEMANA', 'MES', 'ANIO'] as const)(
    'el periodo %s fija la fecha de inicio',
    async (periodo) => {
      await listarMovimientos({ usuarioId: 'a1', rol: 'ADMINISTRADOR', periodo });

      const [{ creadoEn }] = whereUsado().AND as { creadoEn: { gte: Date; lte?: Date } }[];
      expect(creadoEn.gte.getTime()).toBeLessThanOrEqual(Date.now());
      expect(creadoEn.lte).toBeUndefined();
    }
  );

  it('rechaza fechas invalidas con 400', async () => {
    await expect(
      listarMovimientos({ usuarioId: 'a1', rol: 'ADMINISTRADOR', desde: 'ayer' })
    ).rejects.toMatchObject({ statusCode: 400 });
  });

  it('pagina y no expone datos sensibles', async () => {
    repo.contarMovimientos.mockResolvedValue(101);

    const resultado = await listarMovimientos({
      usuarioId: 'a1',
      rol: 'ADMINISTRADOR',
      pagina: 3,
      limite: 25
    });

    expect(repo.buscarMovimientos).toHaveBeenCalledWith({}, 25, 50);
    expect(resultado.metadatos).toEqual({ total: 101, pagina: 3, limite: 25, totalPaginas: 5 });
    expect(resultado.datos[0].usuario).not.toHaveProperty('contrasenaHash');
    expect(resultado.datos[0].bicicleta).not.toHaveProperty('fotoUrl');
    expect(resultado.datos[0].guardia).toEqual({
      id: 'g1',
      nombre: 'Pedro Soto',
      correo: 'guardia@ubiobio.cl'
    });
  });

  it('usa valores por defecto y acota el limite', async () => {
    await listarMovimientos({ usuarioId: 'a1', rol: 'ADMINISTRADOR', pagina: -2, limite: 0 });
    expect(repo.buscarMovimientos).toHaveBeenLastCalledWith({}, 50, 0);

    await listarMovimientos({ usuarioId: 'a1', rol: 'ADMINISTRADOR', limite: 500000 });
    expect(repo.buscarMovimientos).toHaveBeenLastCalledWith({}, 100000, 0);
  });
});

describe('listarMovimientosParaExportar', () => {
  it('respeta el alcance del rol y acota el limite', async () => {
    repo.buscarMovimientosExportacion.mockResolvedValue([] as never);

    await listarMovimientosParaExportar({ usuarioId: 'u1', rol: 'FUNCIONARIO', limite: 999999 });

    expect(repo.buscarMovimientosExportacion).toHaveBeenCalledWith(
      { AND: [{ usuarioId: 'u1' }] },
      100000
    );
  });
});

describe('resumenHistorial', () => {
  it('solo la central puede verlo', async () => {
    await expect(resumenHistorial({ usuarioId: 'g1', rol: 'GUARDIA' })).rejects.toMatchObject({
      statusCode: 403
    });
  });

  it('calcula totales y agrupa por nombre', async () => {
    repo.contarMovimientos
      .mockResolvedValueOnce(10)
      .mockResolvedValueOnce(6)
      .mockResolvedValueOnce(9)
      .mockResolvedValueOnce(1)
      .mockResolvedValueOnce(4)
      .mockResolvedValueOnce(6);
    repo.agruparPorGuardia.mockResolvedValue([
      { validadoPorGuardiaId: 'g1', _count: { _all: 7 } },
      { validadoPorGuardiaId: 'g-borrado', _count: { _all: 3 } }
    ] as never);
    repo.agruparPorBicicletero.mockResolvedValue([
      { bicicleteroId: 'r1', _count: { _all: 10 } }
    ] as never);
    repo.buscarNombresUsuarios.mockResolvedValue([{ id: 'g1', nombre: 'Pedro Soto' }] as never);
    repo.buscarNombresBicicleteros.mockResolvedValue([{ id: 'r1', nombre: 'Biblioteca' }] as never);
    repo.contarPendientesOperativos.mockResolvedValue({
      incidenciasAbiertas: 2,
      solicitudesAbiertas: 1,
      usuariosActivos: 30,
      usuariosInactivos: 1,
      usuariosSinVerificar: 4
    });

    const resumen = await resumenHistorial({ usuarioId: 'a1', rol: 'ADMIN_CENTRAL' });

    expect(resumen).toMatchObject({
      totalMovimientos: 10,
      ingresos: 6,
      retiros: 4,
      confirmados: 9,
      denegados: 1,
      manuales: 4,
      qr: 6,
      incidenciasAbiertas: 2,
      operacionesPorGuardia: { 'Pedro Soto': 7 },
      operacionesPorBicicletero: { Biblioteca: 10 }
    });
    expect(repo.buscarNombresUsuarios).toHaveBeenCalledWith(['g1', 'g-borrado']);
  });
});

describe('opcionesHistorial', () => {
  it('solo la central puede pedir los filtros', async () => {
    await expect(opcionesHistorial('ESTUDIANTE')).rejects.toMatchObject({ statusCode: 403 });
  });

  it('entrega bicicleteros y guardias sin datos internos', async () => {
    (listarBicicleteros as jest.Mock).mockResolvedValue([{ id: 'r1', nombre: 'Biblioteca' }]);
    repo.listarGuardiasActivos.mockResolvedValue([
      {
        id: 'g1',
        nombre: 'Pedro Soto',
        correo: 'guardia@ubiobio.cl',
        rut: '2-7',
        rol: 'GUARDIA',
        correoVerificado: true,
        registroParcial: false,
        cuentaActiva: true,
        contrasenaHash: 'x'
      }
    ] as never);

    const opciones = await opcionesHistorial('ADMINISTRADOR');

    expect(opciones.bicicleteros).toEqual([{ id: 'r1', nombre: 'Biblioteca' }]);
    expect(opciones.guardias[0]).not.toHaveProperty('contrasenaHash');
    expect(opciones.guardias[0]).toMatchObject({ id: 'g1', rol: 'GUARDIA' });
  });
});
