import '../apoyo/configurar-entorno';
import { prismaSimulado } from '../apoyo/prisma-simulado';
import { correosUsuariosDemo } from '../../src/configuracion/datos-iniciales';
import { entorno } from '../../src/configuracion/entorno';
import { quitarUsuariosDemo } from '../../src/modulos/usuarios/cuentas-demo.servicio';

describe('quitarUsuariosDemo', () => {
  beforeEach(() => {
    entorno.datosDemo.habilitados = false;
    prismaSimulado.usuario.count.mockResolvedValue(1);
    prismaSimulado.usuario.updateMany.mockResolvedValue({ count: correosUsuariosDemo.length });
    prismaSimulado.dispositivoToken.deleteMany.mockResolvedValue({ count: 2 });
  });

  it('exige apagar SEED_DEMO_DATA antes de quitar las cuentas', async () => {
    entorno.datosDemo.habilitados = true;

    await expect(quitarUsuariosDemo()).rejects.toThrow('SEED_DEMO_DATA=false');
    expect(prismaSimulado.usuario.updateMany).not.toHaveBeenCalled();
  });

  it('no deja el sistema sin un administrador propio', async () => {
    prismaSimulado.usuario.count.mockResolvedValue(0);

    await expect(quitarUsuariosDemo()).rejects.toThrow('ADMIN_INICIAL_CORREO');
    expect(prismaSimulado.usuario.updateMany).not.toHaveBeenCalled();
  });

  it('solo cuenta administradores verificados que no son demo', async () => {
    await quitarUsuariosDemo();

    expect(prismaSimulado.usuario.count).toHaveBeenCalledWith({
      where: expect.objectContaining({
        rol: 'ADMINISTRADOR',
        cuentaActiva: true,
        correoVerificado: true,
        eliminadoEn: null,
        correo: { notIn: correosUsuariosDemo }
      })
    });
  });

  it('desactiva las cuentas demo, cierra sus sesiones y borra sus dispositivos', async () => {
    await expect(quitarUsuariosDemo()).resolves.toBe(correosUsuariosDemo.length);

    expect(prismaSimulado.usuario.updateMany).toHaveBeenCalledWith({
      where: { correo: { in: correosUsuariosDemo }, eliminadoEn: null },
      data: expect.objectContaining({
        cuentaActiva: false,
        eliminadoEn: expect.any(Date),
        versionSesion: { increment: 1 }
      })
    });
    expect(prismaSimulado.dispositivoToken.deleteMany).toHaveBeenCalledWith({
      where: { usuario: { correo: { in: correosUsuariosDemo } } }
    });
  });
});
