import path from 'path';
import dotenv from 'dotenv';

const cargarVariablesEntorno = () => {
  const rutas = [
    path.resolve(process.cwd(), '.env'),
    path.resolve(process.cwd(), 'backend', '.env'),
    path.resolve(process.cwd(), '..', '.env')
  ];

  for (const ruta of rutas) {
    dotenv.config({ path: ruta });
  }
};

cargarVariablesEntorno();

const valorEntorno = (principal: string, alternativo?: string): string | undefined =>
  process.env[principal] ?? (alternativo ? process.env[alternativo] : undefined);

const convertirNumero = (valor: string | undefined, valorPorDefecto: number): number => {
  const valorConvertido = Number(valor);
  return Number.isNaN(valorConvertido) ? valorPorDefecto : valorConvertido;
};

const convertirBooleano = (valor: string | undefined, valorPorDefecto: boolean): boolean => {
  if (valor === undefined) {
    return valorPorDefecto;
  }

  return ['true', '1', 'yes', 'si'].includes(valor.toLowerCase());
};

const separarLista = (valor: string | undefined, valorPorDefecto: string[]): string[] => {
  if (!valor) {
    return valorPorDefecto;
  }

  return valor
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
};

const convertirTrustProxy = (valor: string | undefined): boolean | number | string => {
  if (!valor || ['false', '0', 'no'].includes(valor.toLowerCase())) {
    return false;
  }

  if (['true', '1', 'yes', 'si'].includes(valor.toLowerCase())) {
    return true;
  }

  const numero = Number(valor);
  return Number.isNaN(numero) ? valor : numero;
};

const ambiente = process.env.NODE_ENV ?? 'development';
const secretoJwt = process.env.JWT_SECRET ?? 'cambiar-este-secreto-en-produccion';
const contrasenaBaseDatos = valorEntorno('DB_PASSWORD', 'POSTGRES_PASSWORD') ?? '';
const contrasenasBaseDatosInvalidas = new Set([
  'ubbike',
  'ubbike_password_demo_2026',
  'CAMBIAR_POR_PASSWORD_DEMO_LOCAL_16_CHARS_MIN',
  'CAMBIAR_POR_CONTRASEÑA_UNICA_PRODUCCION_20_CHARS_MIN'
]);

if (
  secretoJwt === 'cambiar-este-secreto-en-produccion' ||
  secretoJwt.includes('REEMPLAZAR') ||
  secretoJwt.length < 32
) {
  throw new Error('JWT_SECRET debe ser seguro y tener al menos 32 caracteres');
}

if (!contrasenaBaseDatos || contrasenasBaseDatosInvalidas.has(contrasenaBaseDatos)) {
  throw new Error('DB_PASSWORD debe estar configurado y no puede usar valores demo');
}

if (ambiente === 'production' && !process.env.REDIS_URL) {
  throw new Error(
    'REDIS_URL es obligatorio en produccion: sin Redis los refresh tokens no se pueden renovar'
  );
}

const construirUrlBaseDatos = () => {
  if (process.env.DATABASE_URL) {
    return process.env.DATABASE_URL;
  }

  const usuario = encodeURIComponent(valorEntorno('DB_USER', 'POSTGRES_USER') ?? 'ubbike');
  const contrasena = encodeURIComponent(contrasenaBaseDatos);
  const host = process.env.DB_HOST ?? 'localhost';
  const puerto = convertirNumero(valorEntorno('DB_PORT', 'POSTGRES_PORT'), 5432);
  const nombre = encodeURIComponent(valorEntorno('DB_NAME', 'POSTGRES_DB') ?? 'ubbike');

  return `postgresql://${usuario}:${contrasena}@${host}:${puerto}/${nombre}?schema=public`;
};

export const entorno = {
  ambiente,
  puerto: convertirNumero(valorEntorno('PORT', 'BACKEND_PORT'), 3000),
  baseDatos: {
    host: process.env.DB_HOST ?? 'localhost',
    puerto: convertirNumero(valorEntorno('DB_PORT', 'POSTGRES_PORT'), 5432),
    usuario: valorEntorno('DB_USER', 'POSTGRES_USER') ?? 'ubbike',
    contrasena: contrasenaBaseDatos,
    nombre: valorEntorno('DB_NAME', 'POSTGRES_DB') ?? 'ubbike',
    url: construirUrlBaseDatos()
  },
  jwt: {
    secreto: secretoJwt,
    expiracion: process.env.JWT_EXPIRES_IN ?? '2h',
    emisor: process.env.JWT_ISSUER ?? 'ubbike-api',
    audiencia: process.env.JWT_AUDIENCE ?? 'ubbike-app',
    refreshExpiracionDias: convertirNumero(process.env.REFRESH_TOKEN_EXPIRES_DAYS, 30)
  },
  qr: {
    duracionSegundos: convertirNumero(process.env.QR_DURATION_SECONDS, 15)
  },
  limitadorIntentos: {
    factor: convertirNumero(process.env.RATE_LIMIT_FACTOR, 1)
  },
  swagger: {
    habilitado: convertirBooleano(process.env.SWAGGER_ENABLED, ambiente !== 'production')
  },
  cors: {
    origenes: separarLista(process.env.CORS_ORIGINS, [
      'http://localhost:8080',
      'http://localhost:8081',
      'http://localhost:8083',
      'http://127.0.0.1:8080',
      'http://127.0.0.1:8081',
      'http://127.0.0.1:8083'
    ])
  },
  servidor: {
    trustProxy: convertirTrustProxy(process.env.TRUST_PROXY)
  },
  redis: {
    url: process.env.REDIS_URL,
    requerirParaLimitador: convertirBooleano(process.env.REQUIRE_REDIS_RATE_LIMIT, false)
  },
  correo: {
    host: process.env.SMTP_HOST,
    puerto: convertirNumero(process.env.SMTP_PORT, 1025),
    seguro: convertirBooleano(process.env.SMTP_SECURE, false),
    usuario: process.env.SMTP_USER,
    contrasena: process.env.SMTP_PASSWORD,
    remitente: process.env.MAIL_FROM ?? 'UBBike <no-reply@ubbike.local>'
  },
  app: {
    urlFrontend: process.env.FRONTEND_URL ?? 'http://localhost:8081'
  },
  firebase: {
    credencialesPath: process.env.FIREBASE_CREDENTIALS_PATH
  },
  archivos: {
    directorioUploads: process.env.UPLOADS_DIR ?? path.resolve(process.cwd(), 'uploads'),
    rutaPublicaUploads: process.env.UPLOADS_PUBLIC_PATH ?? '/uploads'
  },
  datosDemo: {
    habilitados: convertirBooleano(process.env.SEED_DEMO_DATA, ambiente !== 'production')
  }
};
