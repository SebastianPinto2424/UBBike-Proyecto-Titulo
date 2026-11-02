import '../apoyo/configurar-entorno';

jest.mock('../../src/modulos/acceso/operaciones/acceso.repositorio', () => ({
  buscarUsuarioGestionManual: jest.fn()
}));

import * as accesoRepositorio from '../../src/modulos/acceso/operaciones/acceso.repositorio';
import { buscarCoincidenciaGestionManual } from '../../src/modulos/acceso/operaciones/gestion-manual.servicio';

const repo = accesoRepositorio as jest.Mocked<typeof accesoRepositorio>;

describe('buscarCoincidenciaGestionManual', () => {
  it('exige correo o RUT', async () => {
    await expect(
      buscarCoincidenciaGestionManual({ guardiaId: 'guardia-1', correo: ' ', rut: '' })
    ).rejects.toMatchObject({
      statusCode: 400
    });
    expect(repo.buscarUsuarioGestionManual).not.toHaveBeenCalled();
  });

  it('normaliza el correo y busca todas las variantes del RUT', async () => {
    repo.buscarUsuarioGestionManual.mockResolvedValue(null);

    await expect(
      buscarCoincidenciaGestionManual({
        guardiaId: 'guardia-1',
        correo: ' Ana@Alumnos.UBiobio.cl ',
        rut: '11111111-1'
      })
    ).resolves.toBeNull();

    const criterios = repo.buscarUsuarioGestionManual.mock.calls[0][0] as Record<string, string>[];
    expect(criterios[0]).toEqual({ correo: 'ana@alumnos.ubiobio.cl' });
    expect(criterios.length).toBeGreaterThan(1);
    expect(criterios.slice(1).every((criterio) => 'rut' in criterio)).toBe(true);
  });

  it('entrega la persona y sus bicicletas sin datos internos', async () => {
    repo.buscarUsuarioGestionManual.mockResolvedValue({
      id: 'u1',
      nombre: 'Ana Rojas',
      correo: 'ana@alumnos.ubiobio.cl',
      rut: '11.111.111-1',
      rol: 'ESTUDIANTE',
      correoVerificado: true,
      registroParcial: false,
      cuentaActiva: true,
      contrasenaHash: 'secreto',
      bicicletas: [
        {
          id: 'b1',
          descripcion: 'Urbana azul',
          marca: 'Oxford',
          modelo: null,
          color: 'Azul',
          aro: '26',
          numeroSerie: 'SN1',
          fotoUrl: null,
          activa: true,
          dentroBicicletero: true,
          bicicleteroActual: { id: 'r1', nombre: 'Biblioteca Central', capacidad: 20 }
        }
      ]
    } as never);

    const resultado = await buscarCoincidenciaGestionManual({
      guardiaId: 'guardia-1',
      correo: 'ana@alumnos.ubiobio.cl'
    });

    expect(resultado?.usuario).not.toHaveProperty('contrasenaHash');
    expect(resultado?.usuario.nombre).toBe('Ana Rojas');
    expect(resultado?.bicicletas[0]).toMatchObject({
      id: 'b1',
      dentroBicicletero: true,
      bicicleteroActual: { id: 'r1', nombre: 'Biblioteca Central' }
    });
  });

  it('quien opera no puede buscarse a sí mismo para registrar su propia bicicleta', async () => {
    repo.buscarUsuarioGestionManual.mockResolvedValue({
      id: 'admin-1',
      nombre: 'Administración UBBike',
      correo: 'admin@ubiobio.cl',
      bicicletas: []
    } as never);

    await expect(
      buscarCoincidenciaGestionManual({ guardiaId: 'admin-1', correo: 'admin@ubiobio.cl' })
    ).rejects.toMatchObject({ statusCode: 403 });
  });
});
