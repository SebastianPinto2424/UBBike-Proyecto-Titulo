import '../apoyo/configurar-entorno';
import { prismaSimulado } from '../apoyo/prisma-simulado';
import { contarPendientesOperativos } from '../../src/modulos/historial/historial.repositorio';
it('cuenta todos los registros sin utilizar una muestra de 300', async () => {
  prismaSimulado.incidencia.count.mockResolvedValue(600);
  prismaSimulado.solicitudGuardia.count.mockResolvedValue(700);
  prismaSimulado.usuario.count
    .mockResolvedValueOnce(10)
    .mockResolvedValueOnce(2)
    .mockResolvedValueOnce(3);
  expect(await contarPendientesOperativos()).toEqual({
    incidenciasAbiertas: 600,
    solicitudesAbiertas: 700,
    usuariosActivos: 10,
    usuariosInactivos: 2,
    usuariosSinVerificar: 3
  });
  expect(prismaSimulado.incidencia.findMany).not.toHaveBeenCalled();
  expect(prismaSimulado.usuario.count).toHaveBeenCalledWith({
    where: { eliminadoEn: null, cuentaActiva: true }
  });
});
