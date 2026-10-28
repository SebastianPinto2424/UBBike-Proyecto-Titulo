import '../apoyo/configurar-entorno';

jest.mock('../../src/configuracion/redis', () => ({
  obtenerClienteRedis: jest.fn().mockResolvedValue(null)
}));

jest.mock('../../src/configuracion/prisma', () => ({
  prisma: {
    $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }])
  }
}));

jest.mock('../../src/modulos/autenticacion/enlace-cuenta.servicio', () => ({
  mensajeVerificacionUsada: 'Este enlace ya se usó o no es válido.',
  revisarEnlaceCuenta: jest.fn()
}));

jest.mock('../../src/modulos/autenticacion/registro.servicio', () => ({
  verificarCorreo: jest.fn().mockResolvedValue({ message: 'ok' }),
  completarRegistro: jest.fn().mockResolvedValue({ message: 'ok' }),
  reenviarVerificacionConEnlace: jest.fn().mockResolvedValue(true)
}));

jest.mock('../../src/modulos/autenticacion/contrasena.servicio', () => ({
  cambiarContrasena: jest.fn().mockResolvedValue({ message: 'ok', activacion: true })
}));

import request from 'supertest';
import { aplicacion } from '../../src/aplicacion';
import * as contrasena from '../../src/modulos/autenticacion/contrasena.servicio';
import * as enlaceCuenta from '../../src/modulos/autenticacion/enlace-cuenta.servicio';
import * as registro from '../../src/modulos/autenticacion/registro.servicio';

const servicio = {
  ...(contrasena as jest.Mocked<typeof contrasena>),
  ...(enlaceCuenta as jest.Mocked<typeof enlaceCuenta>),
  ...(registro as jest.Mocked<typeof registro>)
};
const token = 'b'.repeat(64);
const clave = 'Bicicleta#2026ubb';

const enlaceValido = (activacion: boolean, correo = 'pedro.soto@ubiobio.cl') => ({
  valido: true as const,
  correo,
  activacion
});

beforeEach(() => {
  servicio.revisarEnlaceCuenta.mockResolvedValue(enlaceValido(false));
});

describe('páginas de los enlaces', () => {
  it('muestra el formulario con la marca y la política de seguridad propia', async () => {
    const res = await request(aplicacion).get(`/enlaces/cambiar-contrasena?token=${token}`);

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('text/html');
    expect(res.headers['cache-control']).toBe('no-store');
    expect(res.headers['content-security-policy']).toContain("default-src 'none'");
    expect(res.headers['content-security-policy']).toContain("script-src 'self'");
    expect(res.headers['content-security-policy']).not.toContain('upgrade-insecure-requests');
    expect(res.text).toContain('/enlaces/recursos/ubbike-logo.png');
    expect(res.text).not.toContain('Universidad');
    expect(res.text).toContain('Restablece tu contraseña');
    expect(res.text).toContain(
      '<form method="post" action="/enlaces/cambiar-contrasena" novalidate data-formulario>'
    );
    expect(res.text).toMatch(
      /<script src="\/enlaces\/recursos\/formulario-enlace\.js\?v=[a-f0-9]{12}" defer>/
    );
    expect(res.text).not.toContain('ubbike://');
  });

  it('en una activación pide crear la contraseña', async () => {
    servicio.revisarEnlaceCuenta.mockResolvedValue(enlaceValido(true));

    const res = await request(aplicacion).get(`/enlaces/cambiar-contrasena?token=${token}`);

    expect(res.text).toContain('Crea tu contraseña');
    expect(res.text).toContain('Crear contraseña y activar');
    expect(res.text).toContain(
      '<input type="email" autocomplete="username" value="pedro.soto@ubiobio.cl" hidden>'
    );
    expect(res.text).not.toContain('>Correo</label>');
    expect(res.text).toContain('<label for="campo-confirmacion">Confirmar contraseña</label>');
  });

  it('escapa el correo mostrado en la página', async () => {
    servicio.revisarEnlaceCuenta.mockResolvedValue(enlaceValido(false, 'a"<b>@ubiobio.cl'));

    const res = await request(aplicacion).get(`/enlaces/verificar-correo?token=${token}`);

    expect(res.text).not.toContain('a"<b>');
    expect(res.text).toContain('a&quot;&lt;b&gt;@ubiobio.cl');
  });

  it('un enlace vencido muestra el motivo sin formulario', async () => {
    servicio.revisarEnlaceCuenta.mockResolvedValue({
      valido: false,
      titulo: 'Enlace vencido',
      mensaje: 'El enlace para cambiar tu contraseña venció.'
    });

    const res = await request(aplicacion).get(`/enlaces/cambiar-contrasena?token=${token}`);

    expect(res.status).toBe(400);
    expect(res.text).toContain('Enlace vencido');
    expect(res.text).not.toContain('<form');
  });

  it('un enlace de confirmación vencido ofrece enviar uno nuevo', async () => {
    servicio.revisarEnlaceCuenta.mockResolvedValue({
      valido: false,
      titulo: 'Enlace vencido',
      mensaje: 'Por seguridad, el enlace dura 24 horas.',
      reenviable: true
    });

    const res = await request(aplicacion).get(`/enlaces/verificar-correo?token=${token}`);

    expect(res.status).toBe(400);
    expect(res.text).toContain('<form method="post" action="/enlaces/reenviar-verificacion"');
    expect(res.text).toContain(`<input type="hidden" name="token" value="${token}">`);
  });

  it('al pedir otro enlace lo envía y lleva a revisar el correo', async () => {
    const res = await request(aplicacion)
      .post('/enlaces/reenviar-verificacion')
      .type('form')
      .send({ token });

    expect(res.status).toBe(303);
    expect(res.headers.location).toBe('/enlaces/resultado/enlace-reenviado');
    expect(servicio.reenviarVerificacionConEnlace).toHaveBeenCalledWith(token);

    const resultado = await request(aplicacion).get(res.headers.location);
    expect(resultado.status).toBe(200);
    expect(resultado.text).toContain('Revisa tu correo');
  });

  it('no reenvía con un token mal formado ni con un enlace ya usado', async () => {
    const malo = await request(aplicacion)
      .post('/enlaces/reenviar-verificacion')
      .type('form')
      .send({ token: 'xyz' });
    expect(malo.status).toBe(400);
    expect(servicio.reenviarVerificacionConEnlace).not.toHaveBeenCalled();

    servicio.reenviarVerificacionConEnlace.mockResolvedValueOnce(false);
    const usado = await request(aplicacion)
      .post('/enlaces/reenviar-verificacion')
      .type('form')
      .send({ token });
    expect(usado.status).toBe(400);
    expect(usado.text).toContain('Enlace no válido');
  });

  it('un token mal formado o una acción desconocida no consultan la cuenta', async () => {
    const malo = await request(aplicacion).get('/enlaces/completar-registro?token=xyz');
    const desconocida = await request(aplicacion).get(`/enlaces/borrar-todo?token=${token}`);

    expect(malo.status).toBe(400);
    expect(desconocida.status).toBe(404);
    expect(servicio.revisarEnlaceCuenta).not.toHaveBeenCalled();
  });

  it('sirve el logo de la marca', async () => {
    const res = await request(aplicacion).get('/enlaces/recursos/ubbike-logo.png');

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toBe('image/png');
  });

  it('sirve el script que valida los formularios', async () => {
    const res = await request(aplicacion).get('/enlaces/recursos/formulario-enlace.js');

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('javascript');
  });
});

describe('envío de los formularios', () => {
  it('cambiar la contraseña redirige al resultado de activación', async () => {
    const res = await request(aplicacion)
      .post('/enlaces/cambiar-contrasena')
      .type('form')
      .send({ token, contrasena: clave, confirmacion: clave });

    expect(res.status).toBe(303);
    expect(res.headers.location).toBe('/enlaces/resultado/cuenta-activada');
    expect(servicio.cambiarContrasena).toHaveBeenCalledWith(token, clave);
  });

  it('si la contraseña no cumple las reglas vuelve al formulario con el mensaje de la app', async () => {
    const res = await request(aplicacion).post('/enlaces/cambiar-contrasena').type('form').send({
      token,
      contrasena: 'clavesinmayuscula1#',
      confirmacion: 'clavesinmayuscula1#'
    });

    expect(res.status).toBe(400);
    expect(res.text).toContain('Mínimo 12 caracteres con mayúscula, minúscula, número y símbolo.');
    expect(res.text).toContain('aria-invalid="true"');
    expect(res.text).not.toContain('clavesinmayuscula1#');
    expect(servicio.cambiarContrasena).not.toHaveBeenCalled();
  });

  it('si las contraseñas no coinciden vuelve al formulario sin cambiarla', async () => {
    const res = await request(aplicacion)
      .post('/enlaces/cambiar-contrasena')
      .type('form')
      .send({ token, contrasena: clave, confirmacion: 'Bicicleta#2026ubx' });

    expect(res.status).toBe(400);
    expect(res.text).toContain('Las contraseñas no coinciden.');
    expect(res.text).not.toContain(clave);
    expect(servicio.cambiarContrasena).not.toHaveBeenCalled();
  });

  it('confirmar el correo redirige al resultado', async () => {
    const res = await request(aplicacion)
      .post('/enlaces/verificar-correo')
      .type('form')
      .send({ token });

    expect(res.status).toBe(303);
    expect(res.headers.location).toBe('/enlaces/resultado/correo-verificado');
  });

  it('completar el registro redirige al resultado', async () => {
    const res = await request(aplicacion)
      .post('/enlaces/completar-registro')
      .type('form')
      .send({ token, nombre: 'Ana María Rojas Soto', contrasena: clave, confirmacion: clave });

    expect(res.status).toBe(303);
    expect(res.headers.location).toBe('/enlaces/resultado/registro-completado');
  });

  it('un fallo inesperado muestra una página de error', async () => {
    servicio.verificarCorreo.mockRejectedValueOnce(new Error('base caída'));
    const error = jest.spyOn(console, 'error').mockImplementation(() => undefined);

    const res = await request(aplicacion)
      .post('/enlaces/verificar-correo')
      .type('form')
      .send({ token });

    expect(res.status).toBe(500);
    expect(res.text).toContain('No pudimos completar la solicitud');
    error.mockRestore();
  });
});

describe('resultados', () => {
  it.each([
    ['cuenta-activada', 'Cuenta activada'],
    ['registro-completado', 'Cuenta activada'],
    ['contrasena-actualizada', 'Contraseña actualizada'],
    ['correo-verificado', 'Correo confirmado']
  ])('%s muestra su mensaje y abre la app sin avisos', async (resultado, titulo) => {
    const res = await request(aplicacion).get(`/enlaces/resultado/${resultado}`);

    expect(res.status).toBe(200);
    expect(res.text).toContain(titulo);
    expect(res.text).toContain('href="ubbike://abrir"');
    expect(res.text).toContain('Abrir UBBike');
    expect(res.text).not.toContain('<script');
  });

  it('un resultado desconocido responde 404', async () => {
    const res = await request(aplicacion).get('/enlaces/resultado/otro');

    expect(res.status).toBe(404);
  });
});
