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

jest.mock('../../src/modulos/bicicletas/bicicleta.servicio', () => ({
  listarBicicletasUsuario: jest
    .fn()
    .mockResolvedValue([{ id: '00000000-0000-4000-8000-0000000000b1' }]),
  obtenerBicicletaActivaUsuario: jest.fn().mockResolvedValue(null),
  crearBicicleta: jest.fn(),
  actualizarBicicleta: jest.fn().mockResolvedValue({ id: '00000000-0000-4000-8000-0000000000b1' }),
  eliminarBicicleta: jest.fn().mockResolvedValue({ message: 'Bicicleta eliminada correctamente' }),
  activarBicicleta: jest
    .fn()
    .mockResolvedValue({ id: '00000000-0000-4000-8000-0000000000b1', activa: true }),
  desactivarBicicleta: jest
    .fn()
    .mockResolvedValue({ id: '00000000-0000-4000-8000-0000000000b1', activa: false })
}));

jest.mock('../../src/modulos/bicicleteros/bicicletero.servicio', () => ({
  listarBicicleteros: jest.fn().mockResolvedValue([])
}));

jest.mock('../../src/modulos/acceso/asignaciones/asignacion-guardia.servicio', () => ({
  liberarGuardiaDeBicicletero: jest.fn().mockResolvedValue({ message: 'Bicicletero liberado' }),
  asignarGuardiaABicicletero: jest.fn().mockResolvedValue({ id: 'a1' }),
  listarGuardiasHabilitados: jest.fn().mockResolvedValue([])
}));

jest.mock('../../src/modulos/usuarios/usuario.servicio', () => ({
  listarUsuarios: jest.fn().mockResolvedValue([]),
  crearUsuarioAdmin: jest.fn().mockResolvedValue({ id: '00000000-0000-4000-8000-0000000000f1' }),
  eliminarUsuarioAdmin: jest.fn().mockResolvedValue({ message: 'Usuario eliminado' })
}));

jest.mock('../../src/modulos/usuarios/permisos.servicio', () => ({
  actualizarPermisosUsuario: jest
    .fn()
    .mockResolvedValue({ id: '00000000-0000-4000-8000-0000000000d2' })
}));

jest.mock('../../src/modulos/usuarios/invitacion.servicio', () => ({
  reenviarVerificacionCorreoAdmin: jest.fn().mockResolvedValue({ message: 'ok' }),
  reenviarCorreoAccesoAdmin: jest.fn().mockResolvedValue({ message: 'ok' })
}));

jest.mock('../../src/modulos/incidencias/incidencia.servicio', () => ({
  crearIncidencia: jest.fn().mockResolvedValue({ id: '00000000-0000-4000-8000-0000000000e1' }),
  listarIncidencias: jest.fn().mockResolvedValue({ incidencias: [], nextCursor: null })
}));

jest.mock('../../src/modulos/incidencias/seguimiento-incidencia.servicio', () => ({
  actualizarEstadoIncidencia: jest
    .fn()
    .mockResolvedValue({ id: '00000000-0000-4000-8000-0000000000e1' }),
  recordarIncidencia: jest.fn().mockResolvedValue({ id: '00000000-0000-4000-8000-0000000000e1' })
}));

jest.mock('../../src/modulos/notificaciones/notificacion.servicio', () => ({
  listarNotificacionesUsuario: jest
    .fn()
    .mockResolvedValue({ notificaciones: [], nextCursor: null, noLeidas: 0 }),
  marcarNotificacionLeida: jest
    .fn()
    .mockResolvedValue({ id: '00000000-0000-4000-8000-0000000000f1', leida: true }),
  marcarTodasLeidas: jest.fn().mockResolvedValue({ message: 'ok' }),
  registrarDispositivo: jest.fn().mockResolvedValue(undefined),
  eliminarDispositivo: jest.fn().mockResolvedValue(undefined),
  crearNotificacion: jest.fn(),
  notificarUsuariosPorRol: jest.fn(),
  olvidarDispositivosDeUsuario: jest.fn(),
  ejecutarEfectosDiferidos: jest.fn()
}));

import request from 'supertest';
import { aplicacion } from '../../src/aplicacion';
import { prisma } from '../../src/configuracion/prisma';
import { crearTokenSesion } from '../../src/modulos/autenticacion/autenticacion.tokens';
import * as asignaciones from '../../src/modulos/acceso/asignaciones/asignacion-guardia.servicio';
import * as bicicletas from '../../src/modulos/bicicletas/bicicleta.servicio';
import * as bicicleteros from '../../src/modulos/bicicleteros/bicicletero.servicio';
import * as gestionIncidencias from '../../src/modulos/incidencias/incidencia.servicio';
import * as seguimientoIncidencias from '../../src/modulos/incidencias/seguimiento-incidencia.servicio';
import * as notificaciones from '../../src/modulos/notificaciones/notificacion.servicio';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';
import * as invitaciones from '../../src/modulos/usuarios/invitacion.servicio';
import * as permisos from '../../src/modulos/usuarios/permisos.servicio';
import * as cuentas from '../../src/modulos/usuarios/usuario.servicio';

const usuarios = { ...cuentas, ...invitaciones, ...permisos };
const incidencias = { ...gestionIncidencias, ...seguimientoIncidencias };
const buscarUsuario = prisma.usuario.findUnique as jest.Mock;
const uuid = '00000000-0000-4000-8000-000000000001';

const autenticar = (rol: RolUsuario, cambios: Record<string, unknown> = {}) => {
  buscarUsuario.mockResolvedValue({
    id: 'u1',
    rol,
    versionSesion: 1,
    cuentaActiva: true,
    correoVerificado: true,
    debeCambiarContrasena: false,
    ...cambios
  });
  return `Bearer ${crearTokenSesion('u1', rol, 1)}`;
};

describe('autenticación de las rutas protegidas', () => {
  it('sin token responde 401', async () => {
    const res = await request(aplicacion).get('/bicicletas');

    expect(res.status).toBe(401);
  });

  it('con un token firmado con otro secreto responde 401', async () => {
    const res = await request(aplicacion)
      .get('/bicicletas')
      .set('Authorization', 'Bearer eyJhbGciOiJIUzI1NiJ9.e30.firma-falsa');

    expect(res.status).toBe(401);
  });

  it('una sesión invalidada en otro dispositivo responde 401', async () => {
    const token = autenticar(RolUsuario.ESTUDIANTE, { versionSesion: 2 });

    const res = await request(aplicacion).get('/bicicletas').set('Authorization', token);

    expect(res.status).toBe(401);
    expect(res.body.message).toContain('invalidada');
  });

  it('con contraseña temporal pendiente responde 403', async () => {
    const token = autenticar(RolUsuario.GUARDIA, { debeCambiarContrasena: true });

    const res = await request(aplicacion).get('/incidencias').set('Authorization', token);

    expect(res.status).toBe(403);
    expect(res.body.codigo).toBe('CAMBIO_CONTRASENA_REQUERIDO');
  });
});

describe('rutas de bicicleteros', () => {
  it('el listado sabe quién consulta para mostrar los guardias solo al personal', async () => {
    const token = autenticar(RolUsuario.GUARDIA);

    const res = await request(aplicacion).get('/bicicleteros').set('Authorization', token);

    expect(res.status).toBe(200);
    expect(bicicleteros.listarBicicleteros).toHaveBeenCalledWith(RolUsuario.GUARDIA);
  });

  it.each([RolUsuario.ESTUDIANTE, RolUsuario.GUARDIA])(
    '%s no puede liberar el bicicletero de un guardia',
    async (rol) => {
      const res = await request(aplicacion)
        .delete(`/bicicleteros/${uuid}/guardia`)
        .set('Authorization', autenticar(rol));

      expect(res.status).toBe(403);
      expect(asignaciones.liberarGuardiaDeBicicletero).not.toHaveBeenCalled();
    }
  );

  it.each([RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR])(
    '%s libera el bicicletero de un guardia',
    async (rol) => {
      const res = await request(aplicacion)
        .delete(`/bicicleteros/${uuid}/guardia`)
        .set('Authorization', autenticar(rol));

      expect(res.status).toBe(200);
      expect(res.body.message).toBe('Bicicletero liberado');
      expect(asignaciones.liberarGuardiaDeBicicletero).toHaveBeenCalledWith(uuid, 'u1');
    }
  );
});

describe('asignación de guardias desde central', () => {
  const guardiaId = '00000000-0000-4000-8000-000000000002';

  it.each([RolUsuario.ESTUDIANTE, RolUsuario.GUARDIA])(
    '%s no puede asignar guardias ni verlos',
    async (rol) => {
      const token = autenticar(rol);
      const asignar = await request(aplicacion)
        .post(`/bicicleteros/${uuid}/guardia`)
        .set('Authorization', token)
        .send({ guardiaId });
      const listar = await request(aplicacion).get('/guardias').set('Authorization', token);

      expect(asignar.status).toBe(403);
      expect(listar.status).toBe(403);
      expect(asignaciones.asignarGuardiaABicicletero).not.toHaveBeenCalled();
    }
  );

  it.each([RolUsuario.ADMIN_CENTRAL, RolUsuario.ADMINISTRADOR])(
    '%s asigna un guardia y ve la lista de guardias',
    async (rol) => {
      const token = autenticar(rol);
      const asignar = await request(aplicacion)
        .post(`/bicicleteros/${uuid}/guardia`)
        .set('Authorization', token)
        .send({ guardiaId });
      const listar = await request(aplicacion).get('/guardias').set('Authorization', token);

      expect(asignar.status).toBe(200);
      expect(asignaciones.asignarGuardiaABicicletero).toHaveBeenCalledWith(uuid, guardiaId, 'u1');
      expect(listar.status).toBe(200);
      expect(listar.body).toEqual({ guardias: [] });
    }
  );

  it('rechaza una asignación sin un guardia válido', async () => {
    const res = await request(aplicacion)
      .post(`/bicicleteros/${uuid}/guardia`)
      .set('Authorization', autenticar(RolUsuario.ADMIN_CENTRAL))
      .send({ guardiaId: 'no-es-uuid' });

    expect(res.status).toBe(400);
    expect(asignaciones.asignarGuardiaABicicletero).not.toHaveBeenCalled();
  });
});

describe('rutas de bicicletas', () => {
  it('lista las bicicletas del usuario autenticado', async () => {
    const token = autenticar(RolUsuario.ESTUDIANTE);

    const res = await request(aplicacion).get('/bicicletas').set('Authorization', token);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ bicicletas: [{ id: '00000000-0000-4000-8000-0000000000b1' }] });
    expect(bicicletas.listarBicicletasUsuario).toHaveBeenCalledWith('u1');
  });

  it('consulta la bicicleta activa', async () => {
    const token = autenticar(RolUsuario.ESTUDIANTE);

    const res = await request(aplicacion).get('/bicicletas/activa').set('Authorization', token);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ bicicleta: null });
  });

  it('rechaza crear una bicicleta incompleta', async () => {
    const token = autenticar(RolUsuario.ESTUDIANTE);

    const res = await request(aplicacion)
      .post('/bicicletas')
      .set('Authorization', token)
      .send({ descripcion: 'Urbana' });

    expect(res.status).toBe(400);
    expect(bicicletas.crearBicicleta).not.toHaveBeenCalled();
  });

  it('edita, activa, desactiva y elimina sobre la bicicleta indicada', async () => {
    const token = autenticar(RolUsuario.FUNCIONARIO);

    const editar = await request(aplicacion)
      .patch('/bicicletas/00000000-0000-4000-8000-0000000000b1')
      .set('Authorization', token)
      .send({ descripcion: 'Urbana celeste' });
    const activar = await request(aplicacion)
      .patch('/bicicletas/00000000-0000-4000-8000-0000000000b1/activar')
      .set('Authorization', token);
    const desactivar = await request(aplicacion)
      .patch('/bicicletas/00000000-0000-4000-8000-0000000000b1/desactivar')
      .set('Authorization', token);
    const eliminar = await request(aplicacion)
      .delete('/bicicletas/00000000-0000-4000-8000-0000000000b1')
      .set('Authorization', token);

    expect([editar.status, activar.status, desactivar.status, eliminar.status]).toEqual([
      200, 200, 200, 200
    ]);
    expect(bicicletas.actualizarBicicleta).toHaveBeenCalledWith(
      'u1',
      '00000000-0000-4000-8000-0000000000b1',
      {
        descripcion: 'Urbana celeste'
      }
    );
    expect(bicicletas.activarBicicleta).toHaveBeenCalledWith(
      'u1',
      '00000000-0000-4000-8000-0000000000b1'
    );
    expect(bicicletas.desactivarBicicleta).toHaveBeenCalledWith(
      'u1',
      '00000000-0000-4000-8000-0000000000b1'
    );
    expect(eliminar.body.message).toBe('Bicicleta eliminada correctamente');
  });
});

describe('rutas de usuarios', () => {
  it('solo el administrador gestiona cuentas', async () => {
    const token = autenticar(RolUsuario.ADMIN_CENTRAL);

    const res = await request(aplicacion).get('/usuarios').set('Authorization', token);

    expect(res.status).toBe(403);
    expect(usuarios.listarUsuarios).not.toHaveBeenCalled();
  });

  it('interpreta los filtros de la consulta', async () => {
    const token = autenticar(RolUsuario.ADMINISTRADOR);

    const res = await request(aplicacion)
      .get('/usuarios?q=ana&rol=guardia&cuentaActiva=false&correoVerificado=true')
      .set('Authorization', token);

    expect(res.status).toBe(200);
    expect(usuarios.listarUsuarios).toHaveBeenCalledWith({
      q: 'ana',
      rol: RolUsuario.GUARDIA,
      cuentaActiva: false,
      correoVerificado: true
    });
  });

  it('rechaza filtros con valores desconocidos sin consultar', async () => {
    const token = autenticar(RolUsuario.ADMINISTRADOR);

    const res = await request(aplicacion)
      .get('/usuarios?rol=rey&cuentaActiva=quizas')
      .set('Authorization', token);

    expect(res.status).toBe(400);
    expect(res.body.details).toHaveLength(2);
    expect(usuarios.listarUsuarios).not.toHaveBeenCalled();
  });

  it('crea cuentas validando el RUT', async () => {
    const token = autenticar(RolUsuario.ADMINISTRADOR);

    const invalida = await request(aplicacion).post('/usuarios').set('Authorization', token).send({
      nombre: 'Pedro Pablo Soto Rojas',
      correo: 'psoto@ubiobio.cl',
      rut: '11.111.111-2',
      rol: 'GUARDIA'
    });
    const valida = await request(aplicacion).post('/usuarios').set('Authorization', token).send({
      nombre: 'Pedro Pablo Soto Rojas',
      correo: 'psoto@ubiobio.cl',
      rut: '11.111.111-1',
      rol: 'GUARDIA'
    });

    expect(invalida.status).toBe(400);
    expect(valida.status).toBe(201);
    expect(usuarios.crearUsuarioAdmin).toHaveBeenCalledTimes(1);
    expect(usuarios.crearUsuarioAdmin).toHaveBeenCalledWith(
      expect.objectContaining({ correo: 'psoto@ubiobio.cl' }),
      'u1'
    );
  });

  it('actualiza permisos, reenvía correos y elimina dejando al actor', async () => {
    const token = autenticar(RolUsuario.ADMINISTRADOR);

    const permisos = await request(aplicacion)
      .patch('/usuarios/00000000-0000-4000-8000-0000000000d2/permisos')
      .set('Authorization', token)
      .send({ cuentaActiva: false });
    const vacio = await request(aplicacion)
      .patch('/usuarios/00000000-0000-4000-8000-0000000000d2/permisos')
      .set('Authorization', token)
      .send({});
    await request(aplicacion)
      .post('/usuarios/00000000-0000-4000-8000-0000000000d2/reenviar-acceso')
      .set('Authorization', token);
    await request(aplicacion)
      .post('/usuarios/00000000-0000-4000-8000-0000000000d2/reenviar-verificacion')
      .set('Authorization', token);
    const eliminar = await request(aplicacion)
      .delete('/usuarios/00000000-0000-4000-8000-0000000000d2')
      .set('Authorization', token);

    expect(permisos.status).toBe(200);
    expect(vacio.status).toBe(400);
    expect(usuarios.actualizarPermisosUsuario).toHaveBeenCalledWith(
      '00000000-0000-4000-8000-0000000000d2',
      { cuentaActiva: false },
      'u1'
    );
    expect(usuarios.reenviarCorreoAccesoAdmin).toHaveBeenCalledWith(
      '00000000-0000-4000-8000-0000000000d2',
      'u1'
    );
    expect(usuarios.reenviarVerificacionCorreoAdmin).toHaveBeenCalledWith(
      '00000000-0000-4000-8000-0000000000d2',
      'u1'
    );
    expect(eliminar.status).toBe(200);
  });
});

describe('rutas de incidencias', () => {
  it('lista con los filtros y la paginación', async () => {
    const token = autenticar(RolUsuario.ADMIN_CENTRAL);

    const res = await request(aplicacion)
      .get(`/incidencias?estado=ABIERTAS&tipo=OTRO&q=soporte&limite=10&cursor=${uuid}`)
      .set('Authorization', token);

    expect(res.status).toBe(200);
    expect(incidencias.listarIncidencias).toHaveBeenCalledWith(
      expect.objectContaining({
        usuarioId: 'u1',
        rol: RolUsuario.ADMIN_CENTRAL,
        estado: 'ABIERTAS',
        tipo: 'OTRO',
        q: 'soporte',
        limite: 10,
        cursor: uuid
      })
    );
  });

  it('valida y registra un reporte', async () => {
    const token = autenticar(RolUsuario.ESTUDIANTE);

    const corta = await request(aplicacion)
      .post('/incidencias')
      .set('Authorization', token)
      .send({ bicicleteroId: uuid, tipo: 'OTRO', descripcion: 'mal' });
    const valida = await request(aplicacion)
      .post('/incidencias')
      .set('Authorization', token)
      .send({ bicicleteroId: uuid, tipo: 'OTRO', descripcion: 'Soporte suelto en la entrada' });

    expect(corta.status).toBe(400);
    expect(valida.status).toBe(201);
    expect(incidencias.crearIncidencia).toHaveBeenCalledWith(
      expect.objectContaining({ usuarioId: 'u1', bicicleteroId: uuid, tipo: 'OTRO' })
    );
  });

  it('cerrar exige respuesta y recordar usa la incidencia indicada', async () => {
    const token = autenticar(RolUsuario.ADMIN_CENTRAL);

    const sinRespuesta = await request(aplicacion)
      .patch('/incidencias/00000000-0000-4000-8000-0000000000e1/estado')
      .set('Authorization', token)
      .send({ estado: 'RESUELTA' });
    const conRespuesta = await request(aplicacion)
      .patch('/incidencias/00000000-0000-4000-8000-0000000000e1/estado')
      .set('Authorization', token)
      .send({ estado: 'RESUELTA', respuesta: 'Se reparó el soporte' });
    const recordar = await request(aplicacion)
      .post('/incidencias/00000000-0000-4000-8000-0000000000e1/recordar')
      .set('Authorization', token);

    expect(sinRespuesta.status).toBe(400);
    expect(conRespuesta.status).toBe(200);
    expect(incidencias.actualizarEstadoIncidencia).toHaveBeenCalledWith(
      expect.objectContaining({
        incidenciaId: '00000000-0000-4000-8000-0000000000e1',
        estado: 'RESUELTA'
      })
    );
    expect(recordar.status).toBe(200);
    expect(incidencias.recordarIncidencia).toHaveBeenCalledWith(
      expect.objectContaining({
        incidenciaId: '00000000-0000-4000-8000-0000000000e1',
        usuarioId: 'u1'
      })
    );
  });
});

describe('rutas de notificaciones', () => {
  it('lista la bandeja con sus filtros', async () => {
    const token = autenticar(RolUsuario.GUARDIA);

    const res = await request(aplicacion)
      .get(`/notificaciones?soloNoLeidas=true&limite=5&cursor=${uuid}`)
      .set('Authorization', token);

    expect(res.status).toBe(200);
    expect(notificaciones.listarNotificacionesUsuario).toHaveBeenCalledWith(
      'u1',
      expect.objectContaining({ soloNoLeidas: true, limite: 5, cursor: uuid })
    );
  });

  it('marca leídas una o todas', async () => {
    const token = autenticar(RolUsuario.GUARDIA);

    const una = await request(aplicacion)
      .patch('/notificaciones/00000000-0000-4000-8000-0000000000f1/leida')
      .set('Authorization', token);
    const todas = await request(aplicacion)
      .patch('/notificaciones/leidas')
      .set('Authorization', token);

    expect(una.status).toBe(200);
    expect(notificaciones.marcarNotificacionLeida).toHaveBeenCalledWith(
      'u1',
      '00000000-0000-4000-8000-0000000000f1'
    );
    expect(todas.status).toBe(200);
  });

  it('registra y elimina el dispositivo push validando el token', async () => {
    const token = autenticar(RolUsuario.ESTUDIANTE);
    const tokenFcm = 'f'.repeat(40);

    const corto = await request(aplicacion)
      .post('/notificaciones/dispositivos')
      .set('Authorization', token)
      .send({ token: 'corto' });
    const registro = await request(aplicacion)
      .post('/notificaciones/dispositivos')
      .set('Authorization', token)
      .send({ token: tokenFcm, plataforma: 'ios' });
    const baja = await request(aplicacion)
      .delete('/notificaciones/dispositivos')
      .set('Authorization', token)
      .send({ token: tokenFcm });

    expect(corto.status).toBe(400);
    expect(registro.status).toBe(201);
    expect(notificaciones.registrarDispositivo).toHaveBeenCalledWith('u1', tokenFcm, 'ios');
    expect(baja.status).toBe(200);
    expect(notificaciones.eliminarDispositivo).toHaveBeenCalledWith('u1', tokenFcm);
  });
});

describe('validación de identificadores y filtros en las rutas', () => {
  it('un id mal formado responde 400 sin llegar al servicio', async () => {
    const token = autenticar(RolUsuario.ESTUDIANTE);

    const res = await request(aplicacion)
      .patch('/bicicletas/no-es-uuid/activar')
      .set('Authorization', token);

    expect(res.status).toBe(400);
    expect(res.body.details).toEqual(['Identificador inválido']);
    expect(bicicletas.activarBicicleta).not.toHaveBeenCalled();
  });

  it('un filtro con valor desconocido responde 400 sin consultar', async () => {
    const token = autenticar(RolUsuario.ADMIN_CENTRAL);

    const res = await request(aplicacion)
      .get('/incidencias?estado=INVENTADO&limite=0')
      .set('Authorization', token);

    expect(res.status).toBe(400);
    expect(res.body.details).toHaveLength(2);
    expect(incidencias.listarIncidencias).not.toHaveBeenCalled();
  });
});
