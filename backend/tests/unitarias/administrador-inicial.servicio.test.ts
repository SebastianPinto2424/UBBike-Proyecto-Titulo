import '../apoyo/configurar-entorno';

jest.mock('../../src/modulos/usuarios/usuario.repositorio', () => ({
  buscarPorCorreo: jest.fn()
}));

jest.mock('../../src/modulos/usuarios/usuario.servicio', () => ({
  crearUsuarioAdmin: jest.fn().mockResolvedValue({ id: 'admin-1' })
}));

import { entorno } from '../../src/configuracion/entorno';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';
import { asegurarAdministradorInicial } from '../../src/modulos/usuarios/administrador-inicial.servicio';
import * as usuarioRepositorio from '../../src/modulos/usuarios/usuario.repositorio';
import { crearUsuarioAdmin } from '../../src/modulos/usuarios/usuario.servicio';

const buscarPorCorreo = usuarioRepositorio.buscarPorCorreo as jest.Mock;
const crearUsuarioAdminMock = crearUsuarioAdmin as jest.Mock;

describe('asegurarAdministradorInicial', () => {
  beforeEach(() => {
    entorno.administradorInicial.correo = 'jefatura@ubiobio.cl';
    entorno.administradorInicial.nombre = 'Jefatura UBBike';
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('no hace nada si no hay correo configurado', async () => {
    entorno.administradorInicial.correo = undefined;

    await expect(asegurarAdministradorInicial()).resolves.toBe(false);
    expect(buscarPorCorreo).not.toHaveBeenCalled();
    expect(crearUsuarioAdminMock).not.toHaveBeenCalled();
  });

  it('crea la cuenta e invita a definir contraseña cuando no existe', async () => {
    buscarPorCorreo.mockResolvedValue(null);

    await expect(asegurarAdministradorInicial()).resolves.toBe(true);
    expect(crearUsuarioAdminMock).toHaveBeenCalledWith({
      nombre: 'Jefatura UBBike',
      correo: 'jefatura@ubiobio.cl',
      rol: RolUsuario.ADMINISTRADOR
    });
  });

  it('no toca una cuenta que ya existe', async () => {
    buscarPorCorreo.mockResolvedValue({ id: 'u1', eliminadoEn: null });

    await expect(asegurarAdministradorInicial()).resolves.toBe(false);
    expect(crearUsuarioAdminMock).not.toHaveBeenCalled();
  });

  it('no revive una cuenta eliminada por un administrador', async () => {
    buscarPorCorreo.mockResolvedValue({ id: 'u1', eliminadoEn: new Date() });

    await expect(asegurarAdministradorInicial()).resolves.toBe(false);
    expect(crearUsuarioAdminMock).not.toHaveBeenCalled();
  });
});
