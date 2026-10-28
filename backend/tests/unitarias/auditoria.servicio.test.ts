import '../apoyo/configurar-entorno';
import { prismaSimulado } from '../apoyo/prisma-simulado';
import { registrarAuditoria } from '../../src/modulos/auditoria/auditoria.servicio';
it('registra actor y datos en el cliente transaccional recibido', async () => {
  await registrarAuditoria(
    { actorUsuarioId: 'u', accion: 'PRUEBA', entidad: 'pruebas', datos: { resultado: true } },
    prismaSimulado
  );
  expect(prismaSimulado.auditoriaEvento.create).toHaveBeenCalledWith({
    data: expect.objectContaining({
      actorUsuarioId: 'u',
      accion: 'PRUEBA',
      datos: { resultado: true }
    })
  });
});
