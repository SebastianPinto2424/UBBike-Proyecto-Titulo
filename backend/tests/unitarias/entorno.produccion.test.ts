import '../apoyo/configurar-entorno';

const entornoOriginal = { ...process.env };

const cargarEntorno = (variables: Record<string, string | undefined>) => {
  process.env = { ...entornoOriginal, ...variables };
  let modulo: typeof import('../../src/configuracion/entorno') | undefined;
  jest.isolateModules(() => {
    jest.doMock('dotenv', () => ({ config: jest.fn() }));
    modulo = require('../../src/configuracion/entorno');
  });
  return modulo!.entorno;
};

const produccion = {
  NODE_ENV: 'production',
  REDIS_URL: 'redis://redis:6379',
  JWT_SECRET: 'un-secreto-propio-de-produccion-con-largo-suficiente',
  DB_PASSWORD: 'contrasena-propia-produccion-2026',
  SEED_DEMO_DATA: 'false'
};

describe('configuracion de produccion', () => {
  afterEach(() => {
    process.env = { ...entornoOriginal };
  });

  it('arranca con secretos propios y sin datos demo', () => {
    const entorno = cargarEntorno(produccion);

    expect(entorno.datosDemo.habilitados).toBe(false);
    expect(entorno.swagger.habilitado).toBe(false);
  });

  it('sin SEED_DEMO_DATA, produccion no carga datos demo', () => {
    const entorno = cargarEntorno({ ...produccion, SEED_DEMO_DATA: undefined });

    expect(entorno.datosDemo.habilitados).toBe(false);
  });

  it.each([
    ['JWT_SECRET', 'ubbike_jwt_secret_demo_para_entrega_2026'],
    ['DB_PASSWORD', 'ubbike_local_dev_password_segura_2026'],
    ['JWT_SECRET', '<pon-aqui-un-secreto-largo-de-produccion>']
  ])('rechaza %s de ejemplo cuando se apagan los datos demo', (variable, valor) => {
    expect(() => cargarEntorno({ ...produccion, [variable]: valor })).toThrow('deben ser propios');
  });

  it('permite los valores de ejemplo mientras siguen los datos demo', () => {
    const entorno = cargarEntorno({
      ...produccion,
      SEED_DEMO_DATA: 'true',
      JWT_SECRET: 'ubbike_jwt_secret_demo_para_entrega_2026'
    });

    expect(entorno.datosDemo.habilitados).toBe(true);
  });

  it('exige Redis en produccion', () => {
    expect(() => cargarEntorno({ ...produccion, REDIS_URL: undefined })).toThrow('REDIS_URL');
  });

  it('normaliza el correo del administrador inicial', () => {
    const entorno = cargarEntorno({
      ...produccion,
      ADMIN_INICIAL_CORREO: '  Jefatura@UBiobio.cl ',
      ADMIN_INICIAL_NOMBRE: ''
    });

    expect(entorno.administradorInicial).toEqual({
      correo: 'jefatura@ubiobio.cl',
      nombre: 'Administrador UBBike'
    });
  });

  it.each(['jefatura', 'jefatura@ubiobio', 'jefe tura@ubiobio.cl'])(
    'rechaza un correo de administrador inicial mal escrito: %s',
    (correo) => {
      expect(() => cargarEntorno({ ...produccion, ADMIN_INICIAL_CORREO: correo })).toThrow(
        'ADMIN_INICIAL_CORREO'
      );
    }
  );
});

describe('proxy de confianza', () => {
  afterEach(() => {
    process.env = { ...entornoOriginal };
  });

  it.each<[string | undefined, boolean | number | string]>([
    [undefined, false],
    ['false', false],
    ['1', 1],
    ['2', 2],
    ['true', true],
    ['loopback', 'loopback']
  ])('TRUST_PROXY=%s se interpreta como %p', (valor, esperado) => {
    const entorno = cargarEntorno({ TRUST_PROXY: valor });

    expect(entorno.servidor.confianzaProxy).toBe(esperado);
  });
});

describe('correo de soporte', () => {
  afterEach(() => {
    process.env = { ...entornoOriginal };
  });

  it.each<[string | undefined, string | undefined, string]>([
    ['ayuda@ubiobio.cl', 'envios@gmail.com', 'ayuda@ubiobio.cl'],
    [undefined, 'envios@gmail.com', 'envios@gmail.com'],
    [undefined, 'apikey', 'soporte@ubbike.cl'],
    ['no-es-correo', undefined, 'soporte@ubbike.cl']
  ])('CORREO_SOPORTE=%s y SMTP_USER=%s usan %s', (soporte, usuarioSmtp, esperado) => {
    const entorno = cargarEntorno({ CORREO_SOPORTE: soporte, SMTP_USER: usuarioSmtp });

    expect(entorno.correo.soporte).toBe(esperado);
  });
});
