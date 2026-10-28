import '../apoyo/configurar-entorno';

jest.mock('../../src/configuracion/redis', () => ({
  obtenerClienteRedis: jest.fn().mockResolvedValue(null)
}));

jest.mock('../../src/configuracion/prisma', () => ({
  prisma: {
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    usuario: { findUnique: jest.fn() }
  }
}));

jest.mock('../../src/modulos/acceso/solicitudes/seguimiento-solicitud.servicio', () => ({
  actualizarEstadoSolicitudGuardia: jest
    .fn()
    .mockResolvedValue({ id: '00000000-0000-4000-8000-0000000000c1' }),
  cancelarSolicitudGuardia: jest
    .fn()
    .mockResolvedValue({ id: '00000000-0000-4000-8000-0000000000c1', estado: 'CANCELADA' })
}));

import request from 'supertest';
import { aplicacion } from '../../src/aplicacion';
import { prisma } from '../../src/configuracion/prisma';
import { crearTokenSesion } from '../../src/modulos/autenticacion/autenticacion.tokens';
import * as seguimiento from '../../src/modulos/acceso/solicitudes/seguimiento-solicitud.servicio';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';

const buscarUsuario = prisma.usuario.findUnique as jest.Mock;

const autenticar = (rol: RolUsuario) => {
  buscarUsuario.mockResolvedValue({
    id: 'u1',
    rol,
    versionSesion: 1,
    cuentaActiva: true,
    correoVerificado: true,
    debeCambiarContrasena: false
  });
  return `Bearer ${crearTokenSesion('u1', rol, 1)}`;
};

describe('cancelar una solicitud de atención', () => {
  it('quien la hizo la cancela indicando el motivo', async () => {
    const res = await request(aplicacion)
      .post('/solicitudes-guardia/00000000-0000-4000-8000-0000000000c1/cancelar')
      .set('Authorization', autenticar(RolUsuario.ESTUDIANTE))
      .send({ motivo: 'Ya lo resolví' });

    expect(res.status).toBe(200);
    expect(res.body.solicitud).toMatchObject({ estado: 'CANCELADA' });
    expect(seguimiento.cancelarSolicitudGuardia).toHaveBeenCalledWith(
      'u1',
      '00000000-0000-4000-8000-0000000000c1',
      'Ya lo resolví'
    );
  });

  it('sin motivo responde 400 y no cancela', async () => {
    const res = await request(aplicacion)
      .post('/solicitudes-guardia/00000000-0000-4000-8000-0000000000c1/cancelar')
      .set('Authorization', autenticar(RolUsuario.FUNCIONARIO));

    expect(res.status).toBe(400);
    expect(seguimiento.cancelarSolicitudGuardia).not.toHaveBeenCalled();
  });

  it.each([{ motivo: '' }, { motivo: '   ' }, { motivo: 'ok' }])(
    'rechaza un motivo vacío o de menos de 3 caracteres (%o)',
    async (cuerpo) => {
      const res = await request(aplicacion)
        .post('/solicitudes-guardia/00000000-0000-4000-8000-0000000000c1/cancelar')
        .set('Authorization', autenticar(RolUsuario.ESTUDIANTE))
        .send(cuerpo);

      expect(res.status).toBe(400);
      expect(seguimiento.cancelarSolicitudGuardia).not.toHaveBeenCalled();
    }
  );

  it('rechaza un motivo demasiado largo', async () => {
    const res = await request(aplicacion)
      .post('/solicitudes-guardia/00000000-0000-4000-8000-0000000000c1/cancelar')
      .set('Authorization', autenticar(RolUsuario.ESTUDIANTE))
      .send({ motivo: 'x'.repeat(201) });

    expect(res.status).toBe(400);
    expect(seguimiento.cancelarSolicitudGuardia).not.toHaveBeenCalled();
  });

  it('sin sesión responde 401', async () => {
    const res = await request(aplicacion).post(
      '/solicitudes-guardia/00000000-0000-4000-8000-0000000000c1/cancelar'
    );

    expect(res.status).toBe(401);
  });
});
