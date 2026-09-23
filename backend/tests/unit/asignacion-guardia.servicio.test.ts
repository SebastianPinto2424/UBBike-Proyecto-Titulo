import '../helpers/env-setup';
import { prismaMock } from '../helpers/prisma-mock';
jest.mock('../../src/modulos/notificaciones/notificacion.servicio', () => ({
  crearNotificacion: jest.fn(), ejecutarEfectosDiferidos: jest.fn()
}));
import { seleccionarBicicleteroGuardia, liberarBicicleteroGuardia } from '../../src/modulos/acceso/asignaciones/asignacion-guardia.servicio';

it('no asigna un bicicletero inexistente o inactivo', async () => {
  prismaMock.bicicletero.findFirst.mockResolvedValue(null);
  await expect(seleccionarBicicleteroGuardia('u', 'rack')).rejects.toMatchObject({ statusCode: 404 });
  expect(prismaMock.asignacionGuardia.create).not.toHaveBeenCalled();
});
it('libera asignaciones dentro de una transacción con bloqueo por guardia', async () => {
  await liberarBicicleteroGuardia('u');
  expect(prismaMock.$transaction).toHaveBeenCalled();
  expect(prismaMock.$queryRaw).toHaveBeenCalled();
  expect(prismaMock.asignacionGuardia.updateMany).toHaveBeenCalled();
});
