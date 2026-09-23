import '../helpers/env-setup';
import { prismaMock } from '../helpers/prisma-mock';
import { validarBasePruebas } from '../e2e/helpers/seguridad-base-datos';
import { limitarPagina, validarCursor } from '../../src/comun/utils/paginacion';
import {
  actualizarBicicletero,
  eliminarBicicletero
} from '../../src/modulos/bicicleteros/bicicletero.servicio';
import { conTiempoLimite } from '../../src/comun/utils/tiempo-limite';

describe('protecciones de producción', () => {
  it.each([
    undefined,
    'postgresql://u:p@localhost/ubbike',
    'postgresql://u:p@remoto/ubbike_e2e',
    'postgresql://u:p@localhost/postgres'
  ])('rechaza una base no aislada %s', (url) => {
    expect(() => validarBasePruebas(url, '1')).toThrow();
  });
  it('exige autorización explícita para limpiar datos de prueba', () => {
    expect(() => validarBasePruebas('postgresql://u:p@localhost/ubbike_e2e', undefined)).toThrow();
    expect(
      validarBasePruebas('postgresql://u:p@127.0.0.1:15439/ubbike_e2e_auditoria', '1').pathname
    ).toBe('/ubbike_e2e_auditoria');
  });
  it.each([0, -1, NaN, 1.2, Infinity])('rechaza límite inválido %s', (n) =>
    expect(() => limitarPagina(n)).toThrow()
  );
  it('acota páginas grandes y valida cursores', () => {
    expect(limitarPagina(1000)).toBe(100);
    expect(() => validarCursor('invalido')).toThrow();
  });
  it('no permite reducir capacidad por debajo de la ocupación', async () => {
    prismaMock.bicicletero.findUnique.mockResolvedValue({ id: 'rack' } as never);
    prismaMock.bicicleta.count.mockResolvedValue(5);
    await expect(actualizarBicicletero('rack', { capacidad: 4 })).rejects.toMatchObject({
      statusCode: 409
    });
    expect(prismaMock.bicicletero.update).not.toHaveBeenCalled();
    expect(prismaMock.$queryRaw).toHaveBeenCalled();
  });
  it('no desactiva un bicicletero con guardias asignados', async () => {
    prismaMock.bicicletero.findUnique.mockResolvedValue({ id: 'rack' } as never);
    prismaMock.bicicleta.count.mockResolvedValue(0);
    prismaMock.asignacionGuardia.count.mockResolvedValue(1);
    await expect(eliminarBicicletero('rack')).rejects.toMatchObject({ statusCode: 409 });
  });
  it('corta dependencias que no responden', async () => {
    await expect(conTiempoLimite(new Promise(() => {}), 5)).rejects.toThrow('tiempo límite');
    await expect(conTiempoLimite(Promise.resolve('ok'))).resolves.toBe('ok');
  });
});
