import {
  crearClientePruebas,
  limpiarDatos,
  prepararBaseDatosPruebas,
  urlBaseDatosPruebas
} from './helpers/base-datos-real';

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'secreto-de-e2e-suficientemente-largo-para-pasar-validacion';
process.env.DB_PASSWORD = process.env.POSTGRES_PASSWORD ?? 'contrasena-test-de-16-chars-ok';
process.env.REDIS_URL = '';

const prisma = crearClientePruebas(urlBaseDatosPruebas);

beforeAll(async () => {
  await prepararBaseDatosPruebas();
  await prisma.$connect();
}, 180000);

afterAll(async () => {
  await prisma.$disconnect();
});

beforeEach(async () => {
  await limpiarDatos(prisma);
});

const crearUsuario = (correo: string, rut: string | null) =>
  prisma.usuario.create({
    data: {
      nombre: 'Usuario de prueba',
      correo,
      rut,
      rol: 'ESTUDIANTE',
      contrasenaHash: 'hash-irrelevante-para-la-prueba',
      correoVerificado: true
    }
  });

describe('transacciones reales contra PostgreSQL', () => {
  it('revierte todas las escrituras cuando la transaccion falla', async () => {
    const usuario = await crearUsuario('rollback@alumnos.ubiobio.cl', '11.111.111-1');

    await expect(
      prisma.$transaction(async (db) => {
        await db.bicicletero.create({
          data: { nombre: 'Bicicletero temporal', ubicacion: 'Sector prueba', capacidad: 10 }
        });

        await db.bicicleta.create({
          data: {
            usuarioId: usuario.id,
            descripcion: 'Bicicleta temporal',
            dentroBicicletero: false
          }
        });

        throw new Error('fallo forzado despues de escribir');
      })
    ).rejects.toThrow('fallo forzado');

    expect(await prisma.bicicletero.count()).toBe(0);
    expect(await prisma.bicicleta.count()).toBe(0);
  });

  it('confirma las escrituras cuando la transaccion termina bien', async () => {
    const usuario = await crearUsuario('commit@alumnos.ubiobio.cl', '22.222.222-2');

    await prisma.$transaction(async (db) => {
      const bicicletero = await db.bicicletero.create({
        data: { nombre: 'Bicicletero confirmado', ubicacion: 'Sector prueba', capacidad: 10 }
      });

      await db.bicicleta.create({
        data: {
          usuarioId: usuario.id,
          descripcion: 'Bicicleta confirmada',
          dentroBicicletero: true,
          bicicleteroActualId: bicicletero.id
        }
      });
    });

    expect(await prisma.bicicletero.count()).toBe(1);
    expect(await prisma.bicicleta.count()).toBe(1);
  });

  it('la base rechaza dos usuarios con el mismo RUT', async () => {
    await crearUsuario('primero@alumnos.ubiobio.cl', '33.333.333-3');

    await expect(crearUsuario('segundo@alumnos.ubiobio.cl', '33.333.333-3')).rejects.toMatchObject({
      code: 'P2002'
    });
  });

  it('permite reutilizar el RUT despues de liberarlo de la cuenta eliminada', async () => {
    const anterior = await crearUsuario('anterior@alumnos.ubiobio.cl', '44.444.444-4');

    await prisma.usuario.update({
      where: { id: anterior.id },
      data: {
        eliminadoEn: new Date(),
        rut: null,
        correo: 'anterior@alumnos.ubiobio.cl.eliminado'
      }
    });

    const nuevo = await crearUsuario('anterior@alumnos.ubiobio.cl', '44.444.444-4');

    expect(nuevo.id).not.toBe(anterior.id);
    expect(await prisma.usuario.count()).toBe(2);
  });

  it('la ocupacion solo cuenta bicicletas dentro y no eliminadas', async () => {
    const usuario = await crearUsuario('ocupacion@alumnos.ubiobio.cl', '55.555.555-5');
    const bicicletero = await prisma.bicicletero.create({
      data: { nombre: 'Bicicletero ocupacion', ubicacion: 'Sector prueba', capacidad: 10 }
    });

    await prisma.bicicleta.createMany({
      data: [
        {
          usuarioId: usuario.id,
          descripcion: 'Dentro',
          dentroBicicletero: true,
          bicicleteroActualId: bicicletero.id
        },
        {
          usuarioId: usuario.id,
          descripcion: 'Fuera',
          dentroBicicletero: false,
          bicicleteroActualId: null
        },
        {
          usuarioId: usuario.id,
          descripcion: 'Dentro pero eliminada',
          dentroBicicletero: true,
          bicicleteroActualId: bicicletero.id,
          eliminadoEn: new Date()
        }
      ]
    });

    const ocupados = await prisma.bicicleta.count({
      where: {
        bicicleteroActualId: bicicletero.id,
        dentroBicicletero: true,
        eliminadoEn: null
      }
    });

    expect(ocupados).toBe(1);
  });
});
