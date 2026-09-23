import { execFileSync } from 'node:child_process';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../../src/generated/prisma/client';
import { validarBasePruebas } from './seguridad-base-datos';

export const urlBaseDatosPruebas = validarBasePruebas(
  process.env.TEST_DATABASE_URL,
  process.env.ALLOW_TEST_DATABASE_RESET
).toString();
const clientesAutorizados = new WeakSet<PrismaClient>();
export const crearClientePruebas = (connectionString: string) => {
  validarBasePruebas(connectionString, process.env.ALLOW_TEST_DATABASE_RESET);
  const cliente = new PrismaClient({ adapter: new PrismaPg({ connectionString }) });
  clientesAutorizados.add(cliente);
  return cliente;
};

export const prepararBaseDatosPruebas = async () => {
  validarBasePruebas(urlBaseDatosPruebas, process.env.ALLOW_TEST_DATABASE_RESET);
  execFileSync(process.execPath, [require.resolve('prisma/build/index.js'), 'migrate', 'deploy'], {
    cwd: process.cwd(),
    stdio: 'pipe',
    env: { ...process.env, DATABASE_URL: urlBaseDatosPruebas }
  });
};

export const limpiarDatos = async (prisma: PrismaClient) => {
  if (!clientesAutorizados.has(prisma)) throw new Error('Cliente no autorizado para limpieza');
  const destino = validarBasePruebas(urlBaseDatosPruebas, process.env.ALLOW_TEST_DATABASE_RESET);
  const [actual] = await prisma.$queryRaw<
    Array<{ nombre: string }>
  >`SELECT current_database() AS nombre`;
  if (actual.nombre !== destino.pathname.slice(1))
    throw new Error('La base conectada no coincide con la base de pruebas');
  await prisma.$executeRawUnsafe(`TRUNCATE TABLE entregas_pendientes, auditoria_eventos, notificaciones,
    incidencias, solicitudes_guardia, movimientos, codigos_qr_temporales,
    asignaciones_guardias, bicicletas, bicicleteros, usuarios RESTART IDENTITY CASCADE`);
};
