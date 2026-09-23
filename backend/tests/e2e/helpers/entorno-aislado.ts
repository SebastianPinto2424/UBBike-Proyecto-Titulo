import { validarBasePruebas } from './seguridad-base-datos';
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = validarBasePruebas(
  process.env.TEST_DATABASE_URL,
  process.env.ALLOW_TEST_DATABASE_RESET
).toString();
process.env.DB_PASSWORD = 'contrasena-exclusiva-de-pruebas-aisladas';
process.env.JWT_SECRET = 'secreto-exclusivo-de-pruebas-aisladas-20260914';
process.env.SMTP_HOST = '';
process.env.FIREBASE_CREDENTIALS_PATH = '';
process.env.SEED_DEMO_DATA = 'false';
process.env.SWAGGER_ENABLED = 'false';
process.env.QR_DURATION_SECONDS = '120';
const redis = process.env.TEST_REDIS_URL;
if (
  redis &&
  (!['localhost', '127.0.0.1'].includes(new URL(redis).hostname) ||
    ['6379', '6380', ''].includes(new URL(redis).port))
) {
  throw new Error(
    'Redis de pruebas debe ser una instancia aislada en loopback y puerto distinto a desarrollo'
  );
}
process.env.REDIS_URL = redis ?? '';
