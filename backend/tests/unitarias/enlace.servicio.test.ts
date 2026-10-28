import '../apoyo/configurar-entorno';

jest.mock('../../src/modulos/autenticacion/enlace-cuenta.servicio', () => ({
  revisarEnlaceCuenta: jest.fn()
}));

jest.mock('../../src/modulos/autenticacion/registro.servicio', () => ({
  verificarCorreo: jest.fn().mockResolvedValue({ message: 'ok' }),
  completarRegistro: jest.fn().mockResolvedValue({ message: 'ok' })
}));

jest.mock('../../src/modulos/autenticacion/contrasena.servicio', () => ({
  cambiarContrasena: jest.fn()
}));

import { entorno } from '../../src/configuracion/entorno';
import { ErrorHttp } from '../../src/comun/errores/error-http';
import * as contrasena from '../../src/modulos/autenticacion/contrasena.servicio';
import * as enlaceCuenta from '../../src/modulos/autenticacion/enlace-cuenta.servicio';
import * as registro from '../../src/modulos/autenticacion/registro.servicio';
import {
  crearEnlaceCorreo,
  esAccionEnlace,
  esResultadoEnlace
} from '../../src/modulos/enlaces/enlace.servicio';
import {
  procesarEnlace,
  revisarEnlace
} from '../../src/modulos/enlaces/formulario-enlace.servicio';

const servicio = {
  ...(contrasena as jest.Mocked<typeof contrasena>),
  ...(enlaceCuenta as jest.Mocked<typeof enlaceCuenta>),
  ...(registro as jest.Mocked<typeof registro>)
};
const token = 'a'.repeat(64);
const clave = 'Bicicleta#2026ubb';
const valido = { valido: true as const, correo: 'ana@alumnos.ubiobio.cl', activacion: false };

beforeEach(() => {
  servicio.revisarEnlaceCuenta.mockResolvedValue(valido);
});

describe('enlaces de correo', () => {
  it('reconoce solo las acciones y resultados conocidos', () => {
    expect(esAccionEnlace('verificar-correo')).toBe(true);
    expect(esAccionEnlace('cambiar-contrasena')).toBe(true);
    expect(esAccionEnlace('completar-registro')).toBe(true);
    expect(esAccionEnlace('eliminar-cuenta')).toBe(false);
    expect(esResultadoEnlace('cuenta-activada')).toBe(true);
    expect(esResultadoEnlace('cualquiera')).toBe(false);
  });

  it('arma el enlace sobre la URL pública del backend', () => {
    expect(crearEnlaceCorreo('cambiar-contrasena', token)).toBe(
      `${entorno.app.urlEnlaces}/enlaces/cambiar-contrasena?token=${token}`
    );
  });
});

describe('revisión del enlace', () => {
  it.each(['', 'corto', 'A'.repeat(64), `${token}x`])(
    'rechaza sin consultar la base un token mal formado: %s',
    async (malo) => {
      await expect(revisarEnlace('verificar-correo', malo)).resolves.toMatchObject({
        valido: false,
        titulo: 'Enlace no válido'
      });
      expect(servicio.revisarEnlaceCuenta).not.toHaveBeenCalled();
    }
  );

  it('delega la revisión de un token bien formado', async () => {
    await expect(revisarEnlace('cambiar-contrasena', token)).resolves.toEqual(valido);
    expect(servicio.revisarEnlaceCuenta).toHaveBeenCalledWith('cambiar-contrasena', token);
  });
});

describe('envío de los formularios', () => {
  it('un enlace vencido no ejecuta la acción', async () => {
    servicio.revisarEnlaceCuenta.mockResolvedValue({
      valido: false,
      titulo: 'Enlace vencido',
      mensaje: 'El enlace venció.'
    });

    await expect(procesarEnlace('verificar-correo', { token })).resolves.toEqual({
      tipo: 'error',
      estado: 400,
      titulo: 'Enlace vencido',
      mensaje: 'El enlace venció.'
    });
    expect(servicio.verificarCorreo).not.toHaveBeenCalled();
  });

  it('confirma el correo', async () => {
    await expect(procesarEnlace('verificar-correo', { token })).resolves.toEqual({
      tipo: 'listo',
      resultado: 'correo-verificado'
    });
    expect(servicio.verificarCorreo).toHaveBeenCalledWith(token);
  });

  it.each([
    ['', 'La contraseña es obligatoria.'],
    ['corta', 'Mínimo 12 caracteres con mayúscula, minúscula, número y símbolo.'],
    ['sinmayuscula#2026', 'Mínimo 12 caracteres con mayúscula, minúscula, número y símbolo.'],
    [`Aa1#${'x'.repeat(69)}`, 'Máximo 72 caracteres.']
  ])('valida la contraseña %p con los mensajes de la app', async (contrasena, mensaje) => {
    const proceso = await procesarEnlace('cambiar-contrasena', {
      token,
      contrasena,
      confirmacion: contrasena
    });

    expect(proceso).toEqual({
      tipo: 'formulario',
      token,
      enlace: valido,
      errores: { contrasena: mensaje },
      nombre: ''
    });
    expect(servicio.cambiarContrasena).not.toHaveBeenCalled();
  });

  it('pide la contraseña aunque el formulario no la envíe', async () => {
    await expect(procesarEnlace('cambiar-contrasena', { token })).resolves.toMatchObject({
      tipo: 'formulario',
      errores: {
        contrasena: 'La contraseña es obligatoria.',
        confirmacion: 'Las contraseñas no coinciden.'
      }
    });
  });

  it.each([
    ['otra contraseña', 'Bicicleta#2026ubx'],
    ['la confirmación vacía', ''],
    ['sin confirmación', undefined]
  ])('si la confirmación no coincide (%s) no cambia la contraseña', async (_caso, confirmacion) => {
    await expect(
      procesarEnlace('cambiar-contrasena', { token, contrasena: clave, confirmacion })
    ).resolves.toEqual({
      tipo: 'formulario',
      token,
      enlace: valido,
      errores: { confirmacion: 'Las contraseñas no coinciden.' },
      nombre: ''
    });
    expect(servicio.cambiarContrasena).not.toHaveBeenCalled();
  });

  it('con ambos campos vacíos solo pide la contraseña, igual que la app', async () => {
    await expect(
      procesarEnlace('cambiar-contrasena', { token, contrasena: '', confirmacion: '' })
    ).resolves.toMatchObject({
      errores: { contrasena: 'La contraseña es obligatoria.' }
    });
    await expect(
      procesarEnlace('cambiar-contrasena', { token, contrasena: '', confirmacion: '' })
    ).resolves.not.toHaveProperty('errores.confirmacion');
  });

  it.each([
    [true, 'cuenta-activada'],
    [false, 'contrasena-actualizada']
  ])('si la activación es %s el resultado es %s', async (activacion, resultado) => {
    servicio.cambiarContrasena.mockResolvedValue({ message: 'ok', activacion });

    await expect(
      procesarEnlace('cambiar-contrasena', { token, contrasena: clave, confirmacion: clave })
    ).resolves.toEqual({ tipo: 'listo', resultado });
    expect(servicio.cambiarContrasena).toHaveBeenCalledWith(token, clave);
  });

  it('completa el registro con el nombre y la contraseña', async () => {
    await expect(
      procesarEnlace('completar-registro', {
        token,
        nombre: '  Ana   María Rojas Soto ',
        contrasena: clave,
        confirmacion: clave
      })
    ).resolves.toEqual({ tipo: 'listo', resultado: 'registro-completado' });
    expect(servicio.completarRegistro).toHaveBeenCalledWith({
      token,
      nombre: 'Ana María Rojas Soto',
      contrasena: clave
    });
  });

  it('conserva el nombre escrito si hay que corregir el formulario', async () => {
    await expect(
      procesarEnlace('completar-registro', {
        token,
        nombre: 'Ana',
        contrasena: clave,
        confirmacion: clave
      })
    ).resolves.toMatchObject({
      tipo: 'formulario',
      nombre: 'Ana',
      errores: {
        nombre: 'Ingresa dos nombres y dos apellidos (Nombre Nombre Apellido Apellido).'
      }
    });
  });

  it.each([
    ['', 'El nombre es obligatorio.'],
    ['   ', 'El nombre es obligatorio.'],
    [
      'Ana María Rojas Soto Pérez',
      'Ingresa dos nombres y dos apellidos (Nombre Nombre Apellido Apellido).'
    ],
    ['a'.repeat(121), 'Máximo 120 caracteres.']
  ])('valida el nombre %p con los mensajes de la app', async (nombre, mensaje) => {
    await expect(
      procesarEnlace('completar-registro', { token, nombre, contrasena: '' })
    ).resolves.toMatchObject({
      tipo: 'formulario',
      errores: { nombre: mensaje, contrasena: 'La contraseña es obligatoria.' }
    });
    expect(servicio.completarRegistro).not.toHaveBeenCalled();
  });

  it('traduce los errores del servicio en una página de error', async () => {
    servicio.verificarCorreo.mockRejectedValueOnce(
      new ErrorHttp(409, 'Debes completar tu registro antes de activar la cuenta')
    );

    await expect(procesarEnlace('verificar-correo', { token })).resolves.toEqual({
      tipo: 'error',
      estado: 409,
      titulo: 'No se pudo completar',
      mensaje: 'Debes completar tu registro antes de activar la cuenta'
    });
  });

  it('deja pasar los errores inesperados', async () => {
    servicio.verificarCorreo.mockRejectedValueOnce(new Error('base caída'));

    await expect(procesarEnlace('verificar-correo', { token })).rejects.toThrow('base caída');
  });
});
