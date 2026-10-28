import request from 'supertest';
import type { Response } from 'supertest';
import { randomUUID } from 'node:crypto';
import bcrypt from 'bcryptjs';
import {
  activarBicicleta,
  eliminarBicicleta
} from '../../src/modulos/bicicletas/bicicleta.servicio';
import {
  crearClientePruebas,
  limpiarDatos,
  prepararBaseDatosPruebas,
  urlBaseDatosPruebas
} from './apoyo/base-datos-real';
import { prisma as apiPrisma } from '../../src/configuracion/prisma';
import { aplicacion } from '../../src/aplicacion';
import { cerrarRedis } from '../../src/configuracion/redis';
import { registrarGestionManual } from '../../src/modulos/acceso/operaciones/gestion-manual.servicio';
import { confirmarQr } from '../../src/modulos/acceso/operaciones/acceso.servicio';
import { generarQrTemporal, validarQrTemporal } from '../../src/modulos/qr/qr.servicio';
import { crearSolicitudGuardia } from '../../src/modulos/acceso/solicitudes/solicitud-guardia.servicio';
import {
  asignarGuardiaABicicletero,
  liberarBicicleteroGuardia,
  liberarGuardiaDeBicicletero,
  seleccionarBicicleteroGuardia
} from '../../src/modulos/acceso/asignaciones/asignacion-guardia.servicio';
import { cancelarSolicitudGuardia } from '../../src/modulos/acceso/solicitudes/seguimiento-solicitud.servicio';
import { actualizarEstadoSolicitudGuardia } from '../../src/modulos/acceso/solicitudes/seguimiento-solicitud.servicio';
import { cerrarSesion } from '../../src/modulos/autenticacion/autenticacion.servicio';
import { actualizarBicicletero } from '../../src/modulos/bicicleteros/bicicletero.servicio';
import {
  guardarRefreshToken,
  rotarRefreshToken,
  crearTokenSesion
} from '../../src/modulos/autenticacion/autenticacion.tokens';
import {
  listarNotificacionesUsuario,
  crearNotificacion
} from '../../src/modulos/notificaciones/notificacion.servicio';
import { TipoMovimiento } from '../../src/modulos/historial/tipo-movimiento';
import { TipoSolicitudGuardia } from '../../src/modulos/acceso/solicitudes/tipo-solicitud-guardia';
import { TipoNotificacion } from '../../src/modulos/notificaciones/tipo-notificacion';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';
import { eliminarUsuarioAdmin } from '../../src/modulos/usuarios/usuario.servicio';

const prisma = crearClientePruebas(urlBaseDatosPruebas);
beforeAll(prepararBaseDatosPruebas);
beforeEach(() => limpiarDatos(prisma));
afterAll(async () => {
  await prisma.$disconnect();
  await apiPrisma.$disconnect();
  await cerrarRedis();
});

const usuario = (rol: RolUsuario = RolUsuario.ESTUDIANTE) =>
  prisma.usuario.create({
    data: {
      nombre: 'Persona de pruebas',
      correo: `${randomUUID()}@alumnos.ubiobio.cl`,
      contrasenaHash: 'hash-solo-pruebas',
      correoVerificado: true,
      cuentaActiva: true,
      rol
    }
  });
const rack = (capacidad = 1) =>
  prisma.bicicletero.create({
    data: { nombre: `Rack ${randomUUID()}`, ubicacion: 'Laboratorio aislado', capacidad }
  });
const escenario = async () => {
  const [persona, guardia, bicicletero] = await Promise.all([
    usuario(),
    usuario(RolUsuario.ADMIN_CENTRAL),
    rack()
  ]);
  const bicicleta = await prisma.bicicleta.create({
    data: { usuarioId: persona.id, descripcion: 'Bici pruebas', activa: true }
  });
  const datos = {
    guardiaId: guardia.id,
    rol: guardia.rol,
    correo: persona.correo,
    bicicletaId: bicicleta.id,
    bicicleteroId: bicicletero.id,
    tipo: TipoMovimiento.INGRESO
  };
  return { persona, guardia, bicicletero, bicicleta, datos };
};

describe('servicios reales y API sobre PostgreSQL/Redis aislados', () => {
  it('API crea, mueve y quita el punto de un bicicletero sin perder sus datos', async () => {
    const admin = await usuario(RolUsuario.ADMINISTRADOR);
    const token = crearTokenSesion(admin.id, admin.rol, admin.versionSesion);
    const auth = `Bearer ${token}`;
    const creada = await request(aplicacion).post('/bicicleteros').set('Authorization', auth).send({
      nombre: 'Bicicletero mapa',
      ubicacion: 'Acceso FACE',
      capacidad: 80,
      latitud: -36.821728,
      longitud: -73.011604
    });
    expect(creada.status).toBe(201);
    const id = creada.body.bicicletero.id;
    expect(await prisma.bicicletero.findUnique({ where: { id } })).toMatchObject({
      latitud: -36.821728,
      longitud: -73.011604,
      capacidad: 80
    });
    const incompleta = await request(aplicacion)
      .patch(`/bicicleteros/${id}`)
      .set('Authorization', auth)
      .send({ latitud: null, longitud: -73 });
    expect(incompleta.status).toBe(400);
    const movida = await request(aplicacion)
      .patch(`/bicicleteros/${id}`)
      .set('Authorization', auth)
      .send({ latitud: -36.822, longitud: -73.012 });
    expect(movida.status).toBe(200);
    expect(movida.body.bicicletero).toMatchObject({ latitud: -36.822, longitud: -73.012 });
    const quitada = await request(aplicacion)
      .patch(`/bicicleteros/${id}`)
      .set('Authorization', auth)
      .send({ latitud: null, longitud: null });
    expect(quitada.status).toBe(200);
    const lista = await request(aplicacion).get('/bicicleteros').set('Authorization', auth);
    expect(lista.body.bicicleteros).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id, nombre: 'Bicicletero mapa', latitud: null, longitud: null })
      ])
    );
  });
  it('login, perfil, refresh y logout funcionan juntos y revocan sesiones anteriores', async () => {
    const persona = await usuario();
    const contrasena = 'Clave-Solo-Pruebas-2026!';
    await prisma.usuario.update({
      where: { id: persona.id },
      data: { contrasenaHash: await bcrypt.hash(contrasena, 4) }
    });
    const login = await request(aplicacion)
      .post('/autenticacion/login')
      .send({ correo: persona.correo, contrasena });
    expect(login.status).toBe(200);
    const perfil = await request(aplicacion)
      .get('/autenticacion/yo')
      .set('Authorization', `Bearer ${login.body.token}`);
    expect(perfil.status).toBe(200);
    expect(perfil.body.usuario.id).toBe(persona.id);
    const refresh = await request(aplicacion)
      .post('/autenticacion/refresh')
      .send({ usuarioId: persona.id, refreshToken: login.body.refreshToken });
    expect(refresh.status).toBe(200);
    const logout = await request(aplicacion)
      .post('/autenticacion/logout')
      .set('Authorization', `Bearer ${refresh.body.token}`)
      .send({ refreshToken: refresh.body.refreshToken });
    expect(logout.status).toBe(200);
    expect(
      (
        await request(aplicacion)
          .get('/autenticacion/yo')
          .set('Authorization', `Bearer ${refresh.body.token}`)
      ).status
    ).toBe(401);
    expect(
      (
        await request(aplicacion)
          .post('/autenticacion/refresh')
          .send({ usuarioId: persona.id, refreshToken: refresh.body.refreshToken })
      ).status
    ).toBe(401);
  });
  it('activar dos bicicletas simultáneamente conserva una sola activa', async () => {
    const { persona, bicicleta } = await escenario();
    const otra = await prisma.bicicleta.create({
      data: { usuarioId: persona.id, descripcion: 'Otra bicicleta' }
    });
    await Promise.all([
      activarBicicleta(persona.id, bicicleta.id),
      activarBicicleta(persona.id, otra.id)
    ]);
    expect(
      await prisma.bicicleta.count({
        where: { usuarioId: persona.id, activa: true, eliminadoEn: null }
      })
    ).toBe(1);
  });
  it('ingreso y eliminación simultáneos no dejan una bicicleta eliminada dentro', async () => {
    const { persona, bicicleta, datos } = await escenario();
    await Promise.allSettled([
      registrarGestionManual(datos),
      eliminarBicicleta(persona.id, bicicleta.id)
    ]);
    const actual = await prisma.bicicleta.findUniqueOrThrow({ where: { id: bicicleta.id } });
    expect(actual.eliminadoEn != null && actual.dentroBicicletero).toBe(false);
  });
  it('dos ingresos manuales simultáneos generan exactamente un movimiento', async () => {
    const { datos } = await escenario();
    const resultados = await Promise.allSettled([
      registrarGestionManual(datos),
      registrarGestionManual(datos)
    ]);
    expect(resultados.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(await prisma.movimiento.count()).toBe(1);
    expect(await prisma.bicicleta.count({ where: { dentroBicicletero: true } })).toBe(1);
  });
  it('dos bicicletas compitiendo por el último cupo no sobreocupan el rack', async () => {
    const { datos } = await escenario();
    const otra = await usuario();
    const bici = await prisma.bicicleta.create({
      data: { usuarioId: otra.id, descripcion: 'Otra', activa: true }
    });
    const resultados = await Promise.allSettled([
      registrarGestionManual(datos),
      registrarGestionManual({ ...datos, correo: otra.correo, bicicletaId: bici.id })
    ]);
    expect(resultados.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(await prisma.movimiento.count()).toBe(1);
  });
  it('no permite operar un bicicletero desactivado', async () => {
    const { datos, bicicletero } = await escenario();
    await prisma.bicicletero.update({ where: { id: bicicletero.id }, data: { activo: false } });
    await expect(registrarGestionManual(datos)).rejects.toMatchObject({ statusCode: 409 });
    expect(await prisma.movimiento.count()).toBe(0);
  });
  it('no permite reducir capacidad por debajo de bicicletas ingresadas', async () => {
    const { datos, bicicletero } = await escenario();
    await registrarGestionManual(datos);
    await expect(actualizarBicicletero(bicicletero.id, { capacidad: 0 })).rejects.toMatchObject({
      statusCode: 409
    });
  });
  it('QR y operación manual concurrentes no duplican el ingreso', async () => {
    const { datos, persona, bicicleta, bicicletero, guardia } = await escenario();
    const qr = await generarQrTemporal({
      usuarioId: persona.id,
      bicicletaId: bicicleta.id,
      bicicleteroId: bicicletero.id
    });
    await validarQrTemporal(qr.token, { validadorUsuarioId: guardia.id, rol: guardia.rol });
    const resultados = await Promise.allSettled([
      confirmarQr({ token: qr.token, guardiaId: guardia.id, rol: guardia.rol }),
      registrarGestionManual(datos)
    ]);
    expect(resultados.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(await prisma.movimiento.count()).toBe(1);
  });
  it('generar QR simultáneamente deja un solo código vigente', async () => {
    const { persona, bicicleta, bicicletero } = await escenario();
    const datos = {
      usuarioId: persona.id,
      bicicletaId: bicicleta.id,
      bicicleteroId: bicicletero.id
    };
    await Promise.all([generarQrTemporal(datos), generarQrTemporal(datos)]);
    expect(
      await prisma.codigoQrTemporal.count({ where: { usuarioId: persona.id, usado: false } })
    ).toBe(1);
  });
  it('solicitudes concurrentes no crean duplicados', async () => {
    const { persona, bicicletero } = await escenario();
    const datos = {
      usuarioId: persona.id,
      bicicleteroId: bicicletero.id,
      tipo: TipoSolicitudGuardia.GUARDIA_AUSENTE
    };
    await Promise.allSettled([crearSolicitudGuardia(datos), crearSolicitudGuardia(datos)]);
    expect(await prisma.solicitudGuardia.count()).toBe(1);
  });
  it('un guardia no queda con dos asignaciones activas al seleccionar simultáneamente', async () => {
    const guardia = await usuario(RolUsuario.GUARDIA);
    const [a, b] = await Promise.all([rack(), rack()]);
    await Promise.all([
      seleccionarBicicleteroGuardia(guardia.id, a.id),
      seleccionarBicicleteroGuardia(guardia.id, b.id)
    ]);
    expect(
      await prisma.asignacionGuardia.count({ where: { guardiaId: guardia.id, activa: true } })
    ).toBe(1);
  });
  it('dos guardias no gestionan el mismo bicicletero aunque lo elijan a la vez', async () => {
    const [primero, segundo] = await Promise.all([
      usuario(RolUsuario.GUARDIA),
      usuario(RolUsuario.GUARDIA)
    ]);
    const bicicletero = await rack();
    const resultados = await Promise.allSettled([
      seleccionarBicicleteroGuardia(primero.id, bicicletero.id),
      seleccionarBicicleteroGuardia(segundo.id, bicicletero.id)
    ]);

    expect(resultados.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(resultados.find((r) => r.status === 'rejected')).toMatchObject({
      reason: expect.objectContaining({ statusCode: 409 })
    });
    expect(
      await prisma.asignacionGuardia.count({
        where: { bicicleteroId: bicicletero.id, activa: true }
      })
    ).toBe(1);
  });
  it('la base rechaza una segunda asignación activa del mismo bicicletero', async () => {
    const [primero, segundo] = await Promise.all([
      usuario(RolUsuario.GUARDIA),
      usuario(RolUsuario.GUARDIA)
    ]);
    const bicicletero = await rack();
    const asignacion = (guardiaId: string) => ({
      guardiaId,
      bicicleteroId: bicicletero.id,
      iniciaEn: new Date(),
      activa: true
    });
    await prisma.asignacionGuardia.create({ data: asignacion(primero.id) });

    await expect(
      prisma.asignacionGuardia.create({ data: asignacion(segundo.id) })
    ).rejects.toThrow();
  });
  it('una solicitud sin guardia llega al guardia que toma el bicicletero y vuelve a pendientes si lo deja', async () => {
    const [persona, guardia] = await Promise.all([usuario(), usuario(RolUsuario.GUARDIA)]);
    const bicicletero = await rack();
    const solicitud = await crearSolicitudGuardia({
      usuarioId: persona.id,
      bicicleteroId: bicicletero.id,
      tipo: TipoSolicitudGuardia.REQUIERE_SERVICIO
    });
    const estado = () => prisma.solicitudGuardia.findUnique({ where: { id: solicitud.id } });
    expect(await estado()).toMatchObject({ estado: 'PENDIENTE', guardiaAsignadoId: null });

    await seleccionarBicicleteroGuardia(guardia.id, bicicletero.id);
    expect(await estado()).toMatchObject({ estado: 'NOTIFICADA', guardiaAsignadoId: guardia.id });
    expect(
      await prisma.entregaPendiente.count({
        where: { tipo: 'PUSH', datos: { path: ['usuarioId'], equals: guardia.id } }
      })
    ).toBe(1);

    await liberarBicicleteroGuardia(guardia.id);
    expect(await estado()).toMatchObject({ estado: 'PENDIENTE', guardiaAsignadoId: null });
    expect(
      await prisma.notificacion.count({
        where: { usuarioId: persona.id, titulo: 'Solicitud pendiente' }
      })
    ).toBe(1);
  });
  it('una solicitud en camino sigue con su guardia aunque deje el bicicletero', async () => {
    const [persona, guardia] = await Promise.all([usuario(), usuario(RolUsuario.GUARDIA)]);
    const bicicletero = await rack();
    await seleccionarBicicleteroGuardia(guardia.id, bicicletero.id);
    const solicitud = await crearSolicitudGuardia({
      usuarioId: persona.id,
      bicicleteroId: bicicletero.id,
      tipo: TipoSolicitudGuardia.REQUIERE_SERVICIO
    });
    await actualizarEstadoSolicitudGuardia(
      guardia.id,
      RolUsuario.GUARDIA,
      solicitud.id,
      'EN_CAMINO'
    );

    await liberarBicicleteroGuardia(guardia.id);

    expect(await prisma.solicitudGuardia.findUnique({ where: { id: solicitud.id } })).toMatchObject(
      { estado: 'EN_CAMINO', guardiaAsignadoId: guardia.id }
    );
  });
  it('central libera el bicicletero de un guardia y otro puede tomarlo', async () => {
    const [guardia, relevo, central] = await Promise.all([
      usuario(RolUsuario.GUARDIA),
      usuario(RolUsuario.GUARDIA),
      usuario(RolUsuario.ADMIN_CENTRAL)
    ]);
    const bicicletero = await rack();
    await seleccionarBicicleteroGuardia(guardia.id, bicicletero.id);

    await liberarGuardiaDeBicicletero(bicicletero.id, central.id);

    await expect(seleccionarBicicleteroGuardia(relevo.id, bicicletero.id)).resolves.toBeDefined();
    expect(
      await prisma.notificacion.count({
        where: { usuarioId: guardia.id, titulo: 'Bicicletero liberado' }
      })
    ).toBe(1);
  });
  it('central asigna un guardia y al moverlo sus solicitudes sin responder vuelven a pendientes', async () => {
    const [persona, guardia, central] = await Promise.all([
      usuario(),
      usuario(RolUsuario.GUARDIA),
      usuario(RolUsuario.ADMIN_CENTRAL)
    ]);
    const [origen, destino] = await Promise.all([rack(), rack()]);
    const solicitud = await crearSolicitudGuardia({
      usuarioId: persona.id,
      bicicleteroId: origen.id,
      tipo: TipoSolicitudGuardia.REQUIERE_SERVICIO
    });
    const estado = () => prisma.solicitudGuardia.findUnique({ where: { id: solicitud.id } });

    await asignarGuardiaABicicletero(origen.id, guardia.id, central.id);
    expect(await estado()).toMatchObject({ estado: 'NOTIFICADA', guardiaAsignadoId: guardia.id });
    expect(
      await prisma.entregaPendiente.count({
        where: { tipo: 'PUSH', datos: { path: ['usuarioId'], equals: guardia.id } }
      })
    ).toBe(1);

    await asignarGuardiaABicicletero(destino.id, guardia.id, central.id);
    expect(await estado()).toMatchObject({ estado: 'PENDIENTE', guardiaAsignadoId: null });
    expect(
      await prisma.asignacionGuardia.count({ where: { guardiaId: guardia.id, activa: true } })
    ).toBe(1);
  });
  it('quien pidió atención la cancela y el guardia en camino recibe el aviso', async () => {
    const [persona, guardia] = await Promise.all([usuario(), usuario(RolUsuario.GUARDIA)]);
    const bicicletero = await rack();
    await seleccionarBicicleteroGuardia(guardia.id, bicicletero.id);
    const solicitud = await crearSolicitudGuardia({
      usuarioId: persona.id,
      bicicleteroId: bicicletero.id,
      tipo: TipoSolicitudGuardia.REQUIERE_SERVICIO
    });
    await actualizarEstadoSolicitudGuardia(
      guardia.id,
      RolUsuario.GUARDIA,
      solicitud.id,
      'EN_CAMINO'
    );

    await cancelarSolicitudGuardia(persona.id, solicitud.id, 'Ya lo resolví');

    expect(await prisma.solicitudGuardia.findUnique({ where: { id: solicitud.id } })).toMatchObject(
      {
        estado: 'CANCELADA',
        motivoCierre: 'Ya lo resolví',
        cerradaPorUsuarioId: persona.id
      }
    );
    expect(
      await prisma.notificacion.count({
        where: { usuarioId: guardia.id, titulo: 'Solicitud cancelada' }
      })
    ).toBe(1);
  });
  it('cerrar sesión libera el bicicletero del guardia', async () => {
    const guardia = await usuario(RolUsuario.GUARDIA);
    const bicicletero = await rack();
    await seleccionarBicicleteroGuardia(guardia.id, bicicletero.id);

    await prisma.dispositivoToken.create({
      data: { usuarioId: guardia.id, token: `token-${guardia.id}`, plataforma: 'android' }
    });

    await cerrarSesion(guardia.id, undefined, RolUsuario.GUARDIA);

    expect(
      await prisma.asignacionGuardia.count({ where: { guardiaId: guardia.id, activa: true } })
    ).toBe(0);
    expect(await prisma.dispositivoToken.count({ where: { usuarioId: guardia.id } })).toBe(0);
  });
  it('al desactivar a un guardia su bicicletero queda libre para otro', async () => {
    const [guardia, relevo, administrador] = await Promise.all([
      usuario(RolUsuario.GUARDIA),
      usuario(RolUsuario.GUARDIA),
      usuario(RolUsuario.ADMINISTRADOR)
    ]);
    const bicicletero = await rack();
    await seleccionarBicicleteroGuardia(guardia.id, bicicletero.id);

    await eliminarUsuarioAdmin(guardia.id, administrador.id);

    await expect(seleccionarBicicleteroGuardia(relevo.id, bicicletero.id)).resolves.toBeDefined();
    expect(
      await prisma.asignacionGuardia.count({ where: { guardiaId: guardia.id, activa: true } })
    ).toBe(0);
  });
  it('revierte también la cola de entregas si falla la transacción', async () => {
    const persona = await usuario();
    await expect(
      apiPrisma.$transaction(async (db) => {
        await crearNotificacion(
          {
            usuarioId: persona.id,
            titulo: 'Prueba',
            mensaje: 'Prueba',
            tipo: TipoNotificacion.INCIDENCIA
          },
          db,
          []
        );
        throw new Error('rollback');
      })
    ).rejects.toThrow('rollback');
    expect(await prisma.notificacion.count()).toBe(0);
    expect(await prisma.entregaPendiente.count()).toBe(0);
  });
  it('pagina notificaciones sin duplicados y cuenta todas las no leídas', async () => {
    const persona = await usuario();
    await prisma.notificacion.createMany({
      data: Array.from({ length: 45 }, () => ({
        usuarioId: persona.id,
        titulo: 'Prueba',
        mensaje: 'Prueba',
        tipo: TipoNotificacion.INCIDENCIA
      }))
    });
    const a = await listarNotificacionesUsuario(persona.id);
    const b = await listarNotificacionesUsuario(persona.id, { cursor: a.nextCursor! });
    const c = await listarNotificacionesUsuario(persona.id, { cursor: b.nextCursor! });
    expect(a.noLeidas).toBe(45);
    expect(c.nextCursor).toBeNull();
    expect(
      new Set([...a.notificaciones, ...b.notificaciones, ...c.notificaciones].map((n) => n.id)).size
    ).toBe(45);
  });
  it('el refresh se consume una sola vez y está vinculado a versionSesion', async () => {
    if (!process.env.TEST_REDIS_URL)
      throw new Error('Configura TEST_REDIS_URL aislado para esta prueba');
    const id = randomUUID();
    const token = randomUUID();
    await guardarRefreshToken(id, token, 2);
    expect(await rotarRefreshToken(id, token, 'incorrecto', 3)).toBe(false);
    const resultados = await Promise.all([
      rotarRefreshToken(id, token, randomUUID(), 2),
      rotarRefreshToken(id, token, randomUUID(), 2)
    ]);
    expect(resultados.filter(Boolean)).toHaveLength(1);
  });
  it('health verifica PostgreSQL y un PING real de Redis', async () => {
    const respuesta = await request(aplicacion).get('/health');
    expect(respuesta.status).toBe(200);
    expect(respuesta.body.dependencias).toEqual({ baseDatos: true, redis: true });
  });
  it('API exige autenticación y deniega gestión a estudiantes', async () => {
    expect((await request(aplicacion).get('/bicicleteros')).status).toBe(401);
    const persona = await usuario();
    const token = crearTokenSesion(persona.id, persona.rol, persona.versionSesion);
    const respuesta = await request(aplicacion)
      .post('/bicicleteros')
      .set('Authorization', `Bearer ${token}`)
      .send({ nombre: 'No autorizado', ubicacion: 'Prueba', capacidad: 2 });
    expect(respuesta.status).toBe(403);
    expect(await prisma.bicicletero.count()).toBe(0);
  });
  it('API cuenta más de 300 incidencias y pagina únicamente las abiertas', async () => {
    const { persona, guardia, bicicletero } = await escenario();
    await prisma.incidencia.createMany({
      data: Array.from({ length: 351 }, (_, i) => ({
        reportadaPorUsuarioId: persona.id,
        bicicleteroId: bicicletero.id,
        tipo: 'OTRO',
        descripcion: `Incidencia de prueba ${i}`,
        estado: i === 350 ? 'RESUELTA' : 'PENDIENTE'
      }))
    });
    const token = crearTokenSesion(guardia.id, guardia.rol, guardia.versionSesion);
    const resumen = await request(aplicacion)
      .get('/historial/resumen')
      .set('Authorization', `Bearer ${token}`);
    expect(resumen.status).toBe(200);
    expect(resumen.body.resumen.incidenciasAbiertas).toBe(350);
    const encontrados = new Set<string>();
    let cursor: string | null = null;
    do {
      const respuesta: Response = await request(aplicacion)
        .get('/incidencias')
        .query({ estado: 'ABIERTAS', limite: 100, ...(cursor ? { cursor } : {}) })
        .set('Authorization', `Bearer ${token}`);
      expect(respuesta.status).toBe(200);
      for (const incidencia of respuesta.body.incidencias) {
        expect(incidencia.estado).toBe('PENDIENTE');
        encontrados.add(incidencia.id);
      }
      cursor = respuesta.body.nextCursor;
    } while (cursor);
    expect(encontrados.size).toBe(350);
  });
  it('API crea y cierra una incidencia sin permitir dos cierres simultáneos', async () => {
    const { persona, guardia, bicicletero } = await escenario();
    const tokenUsuario = crearTokenSesion(persona.id, persona.rol, persona.versionSesion);
    const tokenCentral = crearTokenSesion(guardia.id, guardia.rol, guardia.versionSesion);
    const creada = await request(aplicacion)
      .post('/incidencias')
      .set('Authorization', `Bearer ${tokenUsuario}`)
      .send({
        bicicleteroId: bicicletero.id,
        tipo: 'OTRO',
        descripcion: 'La puerta necesita revisión técnica'
      });
    expect(creada.status).toBe(201);
    const id = creada.body.incidencia.id;
    const respuestas = await Promise.all(
      [1, 2].map(() =>
        request(aplicacion)
          .patch(`/incidencias/${id}/estado`)
          .set('Authorization', `Bearer ${tokenCentral}`)
          .send({ estado: 'RESUELTA', respuesta: 'Puerta reparada y comprobada' })
      )
    );
    expect(respuestas.map((r) => r.status).sort()).toEqual([200, 409]);
    expect(await prisma.auditoriaEvento.count()).toBeGreaterThan(0);
    expect(await prisma.entregaPendiente.count()).toBeGreaterThan(0);
  });
});
