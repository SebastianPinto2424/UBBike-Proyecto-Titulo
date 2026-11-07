import request from 'supertest';
import {
  crearClientePruebas,
  limpiarDatos,
  prepararBaseDatosPruebas,
  urlBaseDatosPruebas
} from './apoyo/base-datos-real';
import { prisma as apiPrisma } from '../../src/configuracion/prisma';
import { aplicacion } from '../../src/aplicacion';
import { cerrarRedis } from '../../src/configuracion/redis';
import { crearTokenSesion } from '../../src/modulos/autenticacion/autenticacion.tokens';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';

const prisma = crearClientePruebas(urlBaseDatosPruebas);
beforeAll(prepararBaseDatosPruebas);
beforeEach(() => limpiarDatos(prisma));
afterAll(async () => {
  await prisma.$disconnect();
  await apiPrisma.$disconnect();
  await cerrarRedis();
});

const crearUsuario = (rol: RolUsuario, correo: string, rut: string) =>
  prisma.usuario.create({
    data: {
      nombre: 'Persona de pruebas',
      correo,
      rut,
      contrasenaHash: 'hash-solo-pruebas',
      correoVerificado: true,
      cuentaActiva: true,
      rol
    }
  });

const sesion = (usuario: { id: string; rol: RolUsuario; versionSesion: number }) =>
  `Bearer ${crearTokenSesion(usuario.id, usuario.rol, usuario.versionSesion)}`;

describe('separación de funciones: nadie se valida a sí mismo', () => {
  it('un administrador no valida ni registra a mano su propia bicicleta, pero un guardia sí puede', async () => {
    const administrador = await crearUsuario(
      RolUsuario.ADMINISTRADOR,
      'admin.pruebas@ubiobio.cl',
      '22.222.222-2'
    );
    const guardia = await crearUsuario(
      RolUsuario.GUARDIA,
      'guardia.pruebas@gmail.com',
      '11.111.111-1'
    );
    const bicicletero = await prisma.bicicletero.create({
      data: { nombre: 'Rack de pruebas', ubicacion: 'Laboratorio aislado', capacidad: 5 }
    });
    await prisma.asignacionGuardia.create({
      data: { guardiaId: guardia.id, bicicleteroId: bicicletero.id, iniciaEn: new Date() }
    });
    const bicicleta = await prisma.bicicleta.create({
      data: {
        usuarioId: administrador.id,
        descripcion: 'Bicicleta del administrador',
        activa: true
      }
    });

    const generado = await request(aplicacion)
      .post('/qr/generar')
      .set('Authorization', sesion(administrador))
      .send({ bicicletaId: bicicleta.id, bicicleteroId: bicicletero.id });
    expect(generado.status).toBe(201);
    const token = generado.body.qr.token as string;

    const validacionPropia = await request(aplicacion)
      .post('/qr/validar')
      .set('Authorization', sesion(administrador))
      .send({ token });
    expect(validacionPropia.status).toBe(403);
    expect(validacionPropia.body.message).toBe(
      'No puedes registrar ni validar movimientos de tu propia bicicleta. Pídeselo a otro guardia.'
    );

    const busquedaPropia = await request(aplicacion)
      .get('/accesos/manual/buscar')
      .query({ rut: administrador.rut })
      .set('Authorization', sesion(administrador));
    expect(busquedaPropia.status).toBe(403);

    const ingresoManualPropio = await request(aplicacion)
      .post('/accesos/manual')
      .set('Authorization', sesion(administrador))
      .send({
        rut: administrador.rut,
        bicicletaId: bicicleta.id,
        bicicleteroId: bicicletero.id,
        tipo: 'INGRESO'
      });
    expect(ingresoManualPropio.status).toBe(403);
    expect(await prisma.movimiento.count()).toBe(0);

    const validacionGuardia = await request(aplicacion)
      .post('/qr/validar')
      .set('Authorization', sesion(guardia))
      .send({ token });
    expect(validacionGuardia.status).toBe(200);

    const confirmacion = await request(aplicacion)
      .post('/accesos/qr/confirmar')
      .set('Authorization', sesion(guardia))
      .send({ token, bicicleteroId: bicicletero.id });
    expect(confirmacion.status).toBe(201);
    expect(await prisma.movimiento.count({ where: { bicicletaId: bicicleta.id } })).toBe(1);
  });

  it('guardia y central usan sus bicicletas como usuarios y otro guardia valida la del guardia', async () => {
    const guardiaDueno = await crearUsuario(
      RolUsuario.GUARDIA,
      'guardia.dueno@gmail.com',
      '11.111.111-1'
    );
    const guardiaTurno = await crearUsuario(
      RolUsuario.GUARDIA,
      'guardia.turno@gmail.com',
      '33.333.333-3'
    );
    const central = await crearUsuario(
      RolUsuario.ADMIN_CENTRAL,
      'central.pruebas@ubiobio.cl',
      '44.444.444-4'
    );
    const bicicletero = await prisma.bicicletero.create({
      data: { nombre: 'Rack de pruebas', ubicacion: 'Laboratorio aislado', capacidad: 5 }
    });
    const bicicletaGuardia = await prisma.bicicleta.create({
      data: { usuarioId: guardiaDueno.id, descripcion: 'Bicicleta del guardia', activa: true }
    });
    const bicicletaCentral = await prisma.bicicleta.create({
      data: { usuarioId: central.id, descripcion: 'Bicicleta de la central', activa: true }
    });

    const turnoPropio = await request(aplicacion)
      .patch('/guardias/me/bicicletero')
      .set('Authorization', sesion(guardiaDueno))
      .send({ bicicleteroId: bicicletero.id });
    expect(turnoPropio.status).toBe(200);

    const bicicletasGuardia = await request(aplicacion)
      .get('/bicicletas')
      .set('Authorization', sesion(guardiaDueno));
    expect(bicicletasGuardia.status).toBe(200);
    expect(bicicletasGuardia.body.bicicletas.map((b: { id: string }) => b.id)).toEqual([
      bicicletaGuardia.id
    ]);

    const qrGuardia = await request(aplicacion)
      .post('/qr/generar')
      .set('Authorization', sesion(guardiaDueno))
      .send({ bicicletaId: bicicletaGuardia.id, bicicleteroId: bicicletero.id });
    expect(qrGuardia.status).toBe(201);
    const tokenGuardia = qrGuardia.body.qr.token as string;

    const autovalidacion = await request(aplicacion)
      .post('/qr/validar')
      .set('Authorization', sesion(guardiaDueno))
      .send({ token: tokenGuardia });
    expect(autovalidacion.status).toBe(403);
    expect(autovalidacion.body.message).toBe(
      'No puedes registrar ni validar movimientos de tu propia bicicleta. Pídeselo a otro guardia.'
    );

    const liberacion = await request(aplicacion)
      .delete('/guardias/me/bicicletero')
      .set('Authorization', sesion(guardiaDueno));
    expect(liberacion.status).toBe(200);

    const turnoOtroGuardia = await request(aplicacion)
      .patch('/guardias/me/bicicletero')
      .set('Authorization', sesion(guardiaTurno))
      .send({ bicicleteroId: bicicletero.id });
    expect(turnoOtroGuardia.status).toBe(200);

    const validacionOtroGuardia = await request(aplicacion)
      .post('/qr/validar')
      .set('Authorization', sesion(guardiaTurno))
      .send({ token: tokenGuardia });
    expect(validacionOtroGuardia.status).toBe(200);

    const confirmacion = await request(aplicacion)
      .post('/accesos/qr/confirmar')
      .set('Authorization', sesion(guardiaTurno))
      .send({ token: tokenGuardia, bicicleteroId: bicicletero.id });
    expect(confirmacion.status).toBe(201);

    const qrCentral = await request(aplicacion)
      .post('/qr/generar')
      .set('Authorization', sesion(central))
      .send({ bicicletaId: bicicletaCentral.id, bicicleteroId: bicicletero.id });
    expect(qrCentral.status).toBe(201);

    const validacionCentral = await request(aplicacion)
      .post('/qr/validar')
      .set('Authorization', sesion(central))
      .send({ token: qrCentral.body.qr.token });
    expect(validacionCentral.status).toBe(403);
    expect(validacionCentral.body.message).toBe('No tienes permisos para realizar esta acción');

    const historialPropio = await request(aplicacion)
      .get('/historial')
      .query({ alcance: 'PROPIO' })
      .set('Authorization', sesion(guardiaDueno));
    expect(historialPropio.status).toBe(200);
    expect(
      historialPropio.body.datos.map((m: { bicicleta: { id: string } }) => m.bicicleta.id)
    ).toEqual([bicicletaGuardia.id]);

    const historialValidado = await request(aplicacion)
      .get('/historial')
      .set('Authorization', sesion(guardiaDueno));
    expect(historialValidado.status).toBe(200);
    expect(historialValidado.body.datos).toEqual([]);

    const historialTurno = await request(aplicacion)
      .get('/historial')
      .set('Authorization', sesion(guardiaTurno));
    expect(historialTurno.body.datos).toHaveLength(1);

    const historialCentralPropio = await request(aplicacion)
      .get('/historial')
      .query({ alcance: 'PROPIO' })
      .set('Authorization', sesion(central));
    expect(historialCentralPropio.status).toBe(200);
    expect(historialCentralPropio.body.datos).toEqual([]);
  });

  it('el personal pide atención y reporta incidencias, pero nunca atiende lo propio', async () => {
    const guardia = await crearUsuario(
      RolUsuario.GUARDIA,
      'guardia.pide@gmail.com',
      '11.111.111-1'
    );
    const central = await crearUsuario(
      RolUsuario.ADMIN_CENTRAL,
      'central.reporta@ubiobio.cl',
      '44.444.444-4'
    );
    const administrador = await crearUsuario(
      RolUsuario.ADMINISTRADOR,
      'admin.revisa@ubiobio.cl',
      '22.222.222-2'
    );
    const [propio, otro] = await Promise.all([
      prisma.bicicletero.create({
        data: { nombre: 'Rack del turno', ubicacion: 'Laboratorio aislado', capacidad: 5 }
      }),
      prisma.bicicletero.create({
        data: { nombre: 'Rack de otro sector', ubicacion: 'Laboratorio aislado', capacidad: 5 }
      })
    ]);

    await request(aplicacion)
      .patch('/guardias/me/bicicletero')
      .set('Authorization', sesion(guardia))
      .send({ bicicleteroId: propio.id })
      .expect(200);

    const atencionPropia = await request(aplicacion)
      .post('/solicitudes-guardia')
      .set('Authorization', sesion(guardia))
      .send({ bicicleteroId: propio.id, tipo: 'REQUIERE_SERVICIO' });
    expect(atencionPropia.status).toBe(403);

    const atencionEnOtro = await request(aplicacion)
      .post('/solicitudes-guardia')
      .set('Authorization', sesion(guardia))
      .send({ bicicleteroId: otro.id, tipo: 'REQUIERE_SERVICIO', mensaje: 'Mi candado no abre' });
    expect(atencionEnOtro.status).toBe(201);
    const solicitudId = atencionEnOtro.body.solicitud.id as string;

    const misSolicitudes = await request(aplicacion)
      .get('/solicitudes-guardia')
      .query({ alcance: 'PROPIO' })
      .set('Authorization', sesion(guardia));
    expect(misSolicitudes.body.solicitudes.map((s: { id: string }) => s.id)).toEqual([solicitudId]);

    await request(aplicacion)
      .delete('/guardias/me/bicicletero')
      .set('Authorization', sesion(guardia))
      .expect(200);
    await request(aplicacion)
      .patch('/guardias/me/bicicletero')
      .set('Authorization', sesion(guardia))
      .send({ bicicleteroId: otro.id })
      .expect(200);
    expect(
      (await prisma.solicitudGuardia.findUniqueOrThrow({ where: { id: solicitudId } }))
        .guardiaAsignadoId
    ).toBeNull();

    const reporte = await request(aplicacion)
      .post('/incidencias')
      .set('Authorization', sesion(central))
      .send({
        bicicleteroId: propio.id,
        tipo: 'DANO_INFRAESTRUCTURA',
        descripcion: 'El soporte del rack está suelto'
      });
    expect(reporte.status).toBe(201);
    const incidenciaId = reporte.body.incidencia.id as string;

    const gestionPropia = await request(aplicacion)
      .patch(`/incidencias/${incidenciaId}/estado`)
      .set('Authorization', sesion(central))
      .send({ estado: 'EN_REVISION' });
    expect(gestionPropia.status).toBe(403);

    const gestionAdministrador = await request(aplicacion)
      .patch(`/incidencias/${incidenciaId}/estado`)
      .set('Authorization', sesion(administrador))
      .send({ estado: 'EN_REVISION' });
    expect(gestionAdministrador.status).toBe(200);

    const misIncidencias = await request(aplicacion)
      .get('/incidencias')
      .query({ alcance: 'PROPIO' })
      .set('Authorization', sesion(central));
    expect(misIncidencias.body.incidencias.map((i: { id: string }) => i.id)).toEqual([
      incidenciaId
    ]);
  });
});
