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

const clave = 'Bicicleta#2026ubb';

const tokenDelCorreo = async (para: string, accion: string) => {
  const entregas = await prisma.entregaPendiente.findMany({ where: { tipo: 'CORREO' } });
  const correo = entregas
    .map((entrega) => entrega.datos as { para: string; texto: string })
    .find((datos) => datos.para === para);
  const enlace = correo?.texto.match(new RegExp(`/enlaces/${accion}\\?token=(\\S+)`));
  if (!enlace) {
    throw new Error(`No llegó el enlace ${accion} a ${para}`);
  }
  return decodeURIComponent(enlace[1]);
};

const tocarBotonDelCorreo = (accion: string, campos: Record<string, string>) =>
  request(aplicacion).post(`/enlaces/${accion}`).set('Origin', 'null').type('form').send(campos);

const iniciarSesion = (correo: string) =>
  request(aplicacion).post('/autenticacion/login').send({ correo, contrasena: clave });

describe('botones de los correos abiertos en el navegador del celular', () => {
  it('un estudiante se registra, confirma su correo y entra a la app', async () => {
    const correo = 'ana.rojas@alumnos.ubiobio.cl';
    const registro = await request(aplicacion).post('/autenticacion/registro').send({
      nombre: 'Ana María Rojas Soto',
      rut: '11.111.111-1',
      correo,
      contrasena: clave
    });
    expect(registro.status).toBe(201);
    expect((await iniciarSesion(correo)).status).toBe(403);

    const token = await tokenDelCorreo(correo, 'verificar-correo');
    const pagina = await request(aplicacion).get(
      `/enlaces/verificar-correo?token=${encodeURIComponent(token)}`
    );
    expect(pagina.status).toBe(200);

    const boton = await tocarBotonDelCorreo('verificar-correo', { token });
    expect(boton.status).toBe(303);
    expect(boton.headers.location).toBe('/enlaces/resultado/correo-verificado');
    expect((await iniciarSesion(correo)).status).toBe(200);
  });

  it('administración crea un guardia, este crea su contraseña y entra a la app', async () => {
    const administrador = await prisma.usuario.create({
      data: {
        nombre: 'Administración de pruebas',
        correo: 'admin.pruebas@ubiobio.cl',
        contrasenaHash: 'hash-solo-pruebas',
        correoVerificado: true,
        cuentaActiva: true,
        rol: RolUsuario.ADMINISTRADOR
      }
    });
    const correo = 'pedro.soto@gmail.com';
    const creacion = await request(aplicacion)
      .post('/usuarios')
      .set(
        'Authorization',
        `Bearer ${crearTokenSesion(administrador.id, RolUsuario.ADMINISTRADOR, administrador.versionSesion)}`
      )
      .send({
        nombre: 'Pedro Pablo Soto Díaz',
        rut: '22.222.222-2',
        correo,
        rol: RolUsuario.GUARDIA
      });
    expect(creacion.status).toBe(201);

    const token = await tokenDelCorreo(correo, 'cambiar-contrasena');
    const boton = await tocarBotonDelCorreo('cambiar-contrasena', {
      token,
      contrasena: clave,
      confirmacion: clave
    });
    expect(boton.status).toBe(303);
    expect(boton.headers.location).toBe('/enlaces/resultado/cuenta-activada');
    expect((await iniciarSesion(correo)).status).toBe(200);
  });
});
