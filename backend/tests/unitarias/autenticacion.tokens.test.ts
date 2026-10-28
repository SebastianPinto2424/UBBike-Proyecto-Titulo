import '../apoyo/configurar-entorno';
import {
  crearTokenSeguro,
  crearTokenSesion,
  hashearToken,
  resolverRolRegistrable
} from '../../src/modulos/autenticacion/autenticacion.tokens';

jest.mock('../../src/configuracion/redis', () => ({
  obtenerClienteRedis: jest.fn().mockResolvedValue(null)
}));

describe('autenticacion.tokens', () => {
  describe('crearTokenSeguro', () => {
    it('genera un string hexadecimal de 64 caracteres', () => {
      const token = crearTokenSeguro();
      expect(token).toHaveLength(64);
      expect(/^[0-9a-f]+$/.test(token)).toBe(true);
    });

    it('cada llamada genera un token diferente', () => {
      expect(crearTokenSeguro()).not.toBe(crearTokenSeguro());
    });
  });

  describe('hashearToken', () => {
    it('produce el mismo hash para el mismo input', () => {
      const token = 'mi-token-de-prueba';
      expect(hashearToken(token)).toBe(hashearToken(token));
    });

    it('produce hashes distintos para inputs distintos', () => {
      expect(hashearToken('token-a')).not.toBe(hashearToken('token-b'));
    });

    it('produce hash SHA-256 de 64 caracteres hex', () => {
      expect(hashearToken('cualquier-valor')).toHaveLength(64);
    });
  });

  describe('crearTokenSesion', () => {
    it('devuelve un JWT string con tres partes', () => {
      const jwt = crearTokenSesion('user-id-123', 'ESTUDIANTE' as any, 0);
      const partes = jwt.split('.');
      expect(partes).toHaveLength(3);
    });
  });

  describe('resolverRolRegistrable', () => {
    it('asigna ESTUDIANTE a correos @alumnos.ubiobio.cl', () => {
      expect(resolverRolRegistrable('juan@alumnos.ubiobio.cl')).toBe('ESTUDIANTE');
    });

    it('asigna FUNCIONARIO a correos @ubiobio.cl', () => {
      expect(resolverRolRegistrable('juan@ubiobio.cl')).toBe('FUNCIONARIO');
    });

    it('lanza error para correos no institucionales', () => {
      expect(() => resolverRolRegistrable('juan@gmail.com')).toThrow(
        'Debes usar un correo institucional UBB válido'
      );
    });
  });
});
