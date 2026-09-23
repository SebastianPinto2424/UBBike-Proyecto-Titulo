import '../helpers/env-setup';
import { prismaMock } from '../helpers/prisma-mock';
import { contarPendientesOperativos } from '../../src/modulos/historial/historial.repositorio';
it('cuenta todos los registros sin utilizar una muestra de 300', async () => {
  prismaMock.incidencia.count.mockResolvedValue(600);
  prismaMock.solicitudGuardia.count.mockResolvedValue(700);
  prismaMock.usuario.count.mockResolvedValueOnce(10).mockResolvedValueOnce(2).mockResolvedValueOnce(3);
  expect(await contarPendientesOperativos()).toEqual({ incidenciasAbiertas: 600, solicitudesAbiertas: 700, usuariosActivos: 10, usuariosInactivos: 2, usuariosSinVerificar: 3 });
  expect(prismaMock.incidencia.findMany).not.toHaveBeenCalled();
  expect(prismaMock.usuario.count).toHaveBeenCalledWith({ where: { eliminadoEn: null, cuentaActiva: true } });
});
