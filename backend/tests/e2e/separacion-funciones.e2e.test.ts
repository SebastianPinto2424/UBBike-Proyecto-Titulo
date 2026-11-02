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
});
