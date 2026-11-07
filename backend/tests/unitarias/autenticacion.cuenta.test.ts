import '../apoyo/configurar-entorno';

jest.mock('bcrypt', () => ({
  hash: jest.fn(async (texto: string) => `hash:${texto}`),
  compare: jest.fn(async (texto: string, hash: string) => hash === `hash:${texto}`)
}));

jest.mock('../../src/modulos/autenticacion/autenticacion.repositorio', () => ({
  buscarPorId: jest.fn(),
  buscarPorCorreo: jest.fn(),
  buscarPorTokenVerificacion: jest.fn(),
  buscarRegistroParcialPorToken: jest.fn(),
  buscarPorTokenCambioContrasena: jest.fn(),
  limpiarTokenVerificacion: jest.fn().mockResolvedValue(undefined),
  marcarCorreoVerificado: jest.fn(),
  completarRegistroParcial: jest.fn(),
  guardarTokenCambioContrasena: jest.fn(),
  actualizarContrasena: jest.fn().mockResolvedValue(undefined),
  actualizar: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/autenticacion/autenticacion.tokens', () => ({
  ...jest.requireActual('../../src/modulos/autenticacion/autenticacion.tokens'),
  revocarTokenRenovacion: jest.fn().mockResolvedValue(undefined),
  revocarTodosLosTokensRenovacion: jest.fn().mockResolvedValue(undefined),
  rotarTokenRenovacion: jest.fn()
}));

jest.mock('../../src/modulos/correos/cuenta.plantillas', () => {
  const correo = { asunto: 'a', texto: 't', html: 'h' };
  return {
    crearCorreoCambioContrasena: jest.fn().mockReturnValue(correo),
    crearCorreoContrasenaActualizada: jest.fn().mockReturnValue(correo),
    crearCorreoCuentaActivada: jest.fn().mockReturnValue(correo),
    crearCorreoCuentaVerificada: jest.fn().mockReturnValue(correo),
    crearCorreoVerificacion: jest.fn().mockReturnValue(correo)
  };
});

jest.mock('../../src/modulos/correos/correo.servicio', () => ({
  enviarCorreo: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/notificaciones/notificacion.servicio', () => ({
  crearNotificacion: jest.fn().mockResolvedValue(undefined),
  notificarUsuariosPorRol: jest.fn().mockResolvedValue(undefined),
  olvidarDispositivosDeUsuario: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/acceso/asignaciones/asignacion-guardia.servicio', () => ({
  liberarBicicleteroGuardia: jest.fn().mockResolvedValue({ message: 'ok' })
}));

jest.mock('../../src/modulos/auditoria/auditoria.servicio', () => ({
  registrarAuditoria: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/tiempo-real/tiempo-real', () => ({
  cerrarSesionesTiempoReal: jest.fn()
}));

jest.mock('../../src/modulos/usuarios/usuario.eventos', () => ({
  emitirCambioUsuarios: jest.fn()
}));

import jwt from 'jsonwebtoken';
import * as repositorio from '../../src/modulos/autenticacion/autenticacion.repositorio';
import {
  cambiarContrasena,
  cambiarContrasenaSesion,
  solicitarCambioContrasena
} from '../../src/modulos/autenticacion/contrasena.servicio';
import {
  cerrarSesion,
  obtenerUsuarioActual,
  refrescarToken
} from '../../src/modulos/autenticacion/autenticacion.servicio';
import {
  completarRegistro,
  mensajeReenvioVerificacion,
  reenviarVerificacion,
  reenviarVerificacionConEnlace,
  verificarCorreo
} from '../../src/modulos/autenticacion/registro.servicio';
import { revisarEnlaceCuenta } from '../../src/modulos/autenticacion/enlace-cuenta.servicio';
import {
  hashearToken,
  revocarTokenRenovacion,
  revocarTodosLosTokensRenovacion,
  rotarTokenRenovacion
} from '../../src/modulos/autenticacion/autenticacion.tokens';
import {
  crearCorreoCambioContrasena,
  crearCorreoContrasenaActualizada,
  crearCorreoCuentaActivada,
  crearCorreoVerificacion
} from '../../src/modulos/correos/cuenta.plantillas';
import { enviarCorreo } from '../../src/modulos/correos/correo.servicio';
import { crearNotificacion } from '../../src/modulos/notificaciones/notificacion.servicio';
import { registrarAuditoria } from '../../src/modulos/auditoria/auditoria.servicio';
import { entorno } from '../../src/configuracion/entorno';
import { liberarBicicleteroGuardia } from '../../src/modulos/acceso/asignaciones/asignacion-guardia.servicio';
import { olvidarDispositivosDeUsuario } from '../../src/modulos/notificaciones/notificacion.servicio';
import { emitirCambioUsuarios } from '../../src/modulos/usuarios/usuario.eventos';
import { cerrarSesionesTiempoReal } from '../../src/tiempo-real/tiempo-real';

const repo = repositorio as jest.Mocked<typeof repositorio>;
const enMinutos = (minutos: number) => new Date(Date.now() + minutos * 60 * 1000);

const crearUsuario = (cambios: Record<string, unknown> = {}) =>
  ({
    id: 'u1',
    nombre: 'Ana Rojas',
    correo: 'ana@alumnos.ubiobio.cl',
    rut: null,
    rol: 'ESTUDIANTE',
    contrasenaHash: 'hash:Actual#2026segura',
    correoVerificado: true,
    registroParcial: false,
    debeCambiarContrasena: false,
    cuentaActiva: true,
    versionSesion: 3,
    tokenVerificacionCorreoExpiraEn: enMinutos(60),
    tokenCambioContrasenaExpiraEn: enMinutos(20),
    eliminadoEn: null,
    creadoEn: new Date(),
    actualizadoEn: new Date(),
    ...cambios
  }) as never;

describe('obtenerUsuarioActual', () => {
  it('responde 404 si la cuenta no existe', async () => {
    repo.buscarPorId.mockResolvedValue(null);

    await expect(obtenerUsuarioActual('u9')).rejects.toMatchObject({ statusCode: 404 });
  });

  it('nunca expone el hash de la contraseña', async () => {
    repo.buscarPorId.mockResolvedValue(crearUsuario());

    const usuario = await obtenerUsuarioActual('u1');

    expect(usuario).toMatchObject({ id: 'u1', correo: 'ana@alumnos.ubiobio.cl' });
    expect(usuario).not.toHaveProperty('contrasenaHash');
    expect(usuario).not.toHaveProperty('versionSesion');
  });
});

describe('verificarCorreo', () => {
  it('busca por el hash del token, no por el token', async () => {
    repo.buscarPorTokenVerificacion.mockResolvedValue(null);

    await expect(verificarCorreo('a'.repeat(64))).rejects.toMatchObject({ statusCode: 400 });
    expect(repo.buscarPorTokenVerificacion).toHaveBeenCalledWith(hashearToken('a'.repeat(64)));
  });

  it('un registro parcial debe completarse primero', async () => {
    repo.buscarPorTokenVerificacion.mockResolvedValue(crearUsuario({ registroParcial: true }));

    await expect(verificarCorreo('token')).rejects.toMatchObject({ statusCode: 409 });
  });

  it('activa la cuenta, avisa y deja auditoria', async () => {
    repo.buscarPorTokenVerificacion.mockResolvedValue(crearUsuario({ correoVerificado: false }));
    repo.marcarCorreoVerificado.mockResolvedValue(crearUsuario());

    const resultado = await verificarCorreo('token');

    expect(repo.marcarCorreoVerificado).toHaveBeenCalledWith('u1');
    expect(crearNotificacion).toHaveBeenCalledWith(
      expect.objectContaining({ usuarioId: 'u1', titulo: 'Cuenta activada' })
    );
    expect(enviarCorreo).toHaveBeenCalledWith(
      expect.objectContaining({ para: 'ana@alumnos.ubiobio.cl' })
    );
    expect(registrarAuditoria).toHaveBeenCalledWith(
      expect.objectContaining({ accion: 'CORREO_VERIFICADO' })
    );
    expect(resultado.usuario).not.toHaveProperty('contrasenaHash');
  });
});

describe('completarRegistro', () => {
  const datos = { token: 'token', nombre: 'Ana Rojas', contrasena: 'Nueva#Clave2026' };

  it('rechaza un enlace que no corresponde a un registro parcial', async () => {
    repo.buscarRegistroParcialPorToken.mockResolvedValue(null);

    await expect(completarRegistro(datos)).rejects.toMatchObject({ statusCode: 400 });
  });

  it('un enlace vencido se invalida', async () => {
    repo.buscarRegistroParcialPorToken.mockResolvedValue(
      crearUsuario({ registroParcial: true, tokenVerificacionCorreoExpiraEn: enMinutos(-1) })
    );

    await expect(completarRegistro(datos)).rejects.toMatchObject({
      statusCode: 400,
      message: expect.stringContaining('expiró')
    });
    expect(repo.limpiarTokenVerificacion).toHaveBeenCalledWith('u1');
    expect(repo.completarRegistroParcial).not.toHaveBeenCalled();
  });

  it('guarda el nombre y la contraseña hasheada', async () => {
    repo.buscarRegistroParcialPorToken.mockResolvedValue(crearUsuario({ registroParcial: true }));
    repo.completarRegistroParcial.mockResolvedValue(crearUsuario());

    const resultado = await completarRegistro(datos);

    expect(repo.completarRegistroParcial).toHaveBeenCalledWith('u1', {
      nombre: 'Ana Rojas',
      contrasenaHash: 'hash:Nueva#Clave2026'
    });
    expect(registrarAuditoria).toHaveBeenCalledWith(
      expect.objectContaining({ accion: 'REGISTRO_PARCIAL_COMPLETADO' })
    );
    expect(resultado.message).toBe('Registro completado correctamente');
  });
});

describe('solicitarCambioContrasena', () => {
  it('responde lo mismo si el correo no existe', async () => {
    repo.buscarPorCorreo.mockResolvedValue(null);

    const resultado = await solicitarCambioContrasena('NoExiste@alumnos.ubiobio.cl');

    expect(repo.buscarPorCorreo).toHaveBeenCalledWith('noexiste@alumnos.ubiobio.cl');
    expect(resultado.message).toBe(
      'Si el correo existe, enviaremos instrucciones de recuperación.'
    );
    expect(enviarCorreo).not.toHaveBeenCalled();
  });

  it('guarda solo el hash y envia el enlace puente con el token original', async () => {
    repo.buscarPorCorreo.mockResolvedValue(crearUsuario());
    repo.guardarTokenCambioContrasena.mockResolvedValue(crearUsuario());

    await solicitarCambioContrasena('ana@alumnos.ubiobio.cl');

    const [, hashGuardado, expiraEn] = repo.guardarTokenCambioContrasena.mock.calls[0];
    const enlace = (crearCorreoCambioContrasena as jest.Mock).mock.calls[0][1] as string;
    const token = new URL(enlace).searchParams.get('token')!;

    expect(enlace.startsWith(`${entorno.app.urlEnlaces}/enlaces/cambiar-contrasena?token=`)).toBe(
      true
    );
    expect(token).toMatch(/^[a-f0-9]{64}$/);
    expect(hashGuardado).toBe(hashearToken(token));
    expect(hashGuardado).not.toBe(token);
    expect(expiraEn.getTime() - Date.now()).toBeGreaterThan(29 * 60 * 1000);
    expect(expiraEn.getTime() - Date.now()).toBeLessThanOrEqual(30 * 60 * 1000);
    expect(registrarAuditoria).toHaveBeenCalledWith(
      expect.objectContaining({ accion: 'CAMBIO_CONTRASENA_SOLICITADO' })
    );
  });
});

describe('cambiarContrasena', () => {
  it('rechaza un enlace invalido', async () => {
    repo.buscarPorTokenCambioContrasena.mockResolvedValue(null);

    await expect(cambiarContrasena('token', 'Nueva#Clave2026')).rejects.toMatchObject({
      statusCode: 400
    });
  });

  it('rechaza un enlace vencido', async () => {
    repo.buscarPorTokenCambioContrasena.mockResolvedValue(
      crearUsuario({ tokenCambioContrasenaExpiraEn: enMinutos(-1) })
    );

    await expect(cambiarContrasena('token', 'Nueva#Clave2026')).rejects.toMatchObject({
      statusCode: 400,
      message: expect.stringContaining('expiró')
    });
    expect(repo.actualizarContrasena).not.toHaveBeenCalled();
  });

  it('cambia la contraseña y cierra todas las sesiones', async () => {
    repo.buscarPorTokenCambioContrasena.mockResolvedValue(crearUsuario());

    await cambiarContrasena('token', 'Nueva#Clave2026');

    expect(repo.buscarPorTokenCambioContrasena).toHaveBeenCalledWith(hashearToken('token'));
    expect(repo.actualizarContrasena).toHaveBeenCalledWith('u1', 'hash:Nueva#Clave2026');
    expect(revocarTodosLosTokensRenovacion).toHaveBeenCalledWith('u1');
    expect(cerrarSesionesTiempoReal).toHaveBeenCalledWith('u1', 'CONTRASENA_ACTUALIZADA');
    expect(crearCorreoContrasenaActualizada).toHaveBeenCalledWith('Ana Rojas');
    expect(crearCorreoCuentaActivada).not.toHaveBeenCalled();
    expect(emitirCambioUsuarios).not.toHaveBeenCalled();
  });

  it('la primera definicion de contraseña activa la cuenta', async () => {
    repo.buscarPorTokenCambioContrasena.mockResolvedValue(
      crearUsuario({ debeCambiarContrasena: true, rol: 'GUARDIA' })
    );

    await cambiarContrasena('token', 'Nueva#Clave2026');

    expect(crearCorreoCuentaActivada).toHaveBeenCalledWith('Ana Rojas', 'GUARDIA');
    expect(crearNotificacion).toHaveBeenCalledWith(
      expect.objectContaining({ titulo: 'Cuenta activada' })
    );
    expect(emitirCambioUsuarios).toHaveBeenCalledTimes(1);
  });
});

describe('cambiarContrasenaSesion', () => {
  it('responde 404 si la cuenta no existe', async () => {
    repo.buscarPorId.mockResolvedValue(null);

    await expect(cambiarContrasenaSesion('u9', 'a', 'b')).rejects.toMatchObject({
      statusCode: 404
    });
  });

  it('exige la contraseña actual correcta', async () => {
    repo.buscarPorId.mockResolvedValue(crearUsuario());

    await expect(
      cambiarContrasenaSesion('u1', 'Equivocada#2026', 'Nueva#Clave2026')
    ).rejects.toMatchObject({ statusCode: 400, message: 'La contraseña actual no es correcta' });
  });

  it('la nueva debe ser distinta', async () => {
    repo.buscarPorId.mockResolvedValue(crearUsuario());

    await expect(
      cambiarContrasenaSesion('u1', 'Actual#2026segura', 'Actual#2026segura')
    ).rejects.toMatchObject({ statusCode: 400 });
  });

  it('guarda la nueva y obliga a iniciar sesion otra vez', async () => {
    repo.buscarPorId.mockResolvedValue(crearUsuario({ debeCambiarContrasena: true }));

    const resultado = await cambiarContrasenaSesion('u1', 'Actual#2026segura', 'Nueva#Clave2026');

    expect(repo.actualizar).toHaveBeenCalledWith('u1', {
      contrasenaHash: 'hash:Nueva#Clave2026',
      debeCambiarContrasena: false,
      versionSesion: { increment: 1 }
    });
    expect(revocarTodosLosTokensRenovacion).toHaveBeenCalledWith('u1');
    expect(registrarAuditoria).toHaveBeenCalledWith(
      expect.objectContaining({ accion: 'CONTRASENA_CAMBIADA_SESION' })
    );
    expect(resultado.message).toContain('Vuelve a iniciar sesión');
    expect(emitirCambioUsuarios).toHaveBeenCalledTimes(1);
  });

  it('un cambio voluntario no avisa a la gestión de usuarios', async () => {
    repo.buscarPorId.mockResolvedValue(crearUsuario());

    await cambiarContrasenaSesion('u1', 'Actual#2026segura', 'Nueva#Clave2026');

    expect(emitirCambioUsuarios).not.toHaveBeenCalled();
  });
});

describe('refrescarToken', () => {
  it.each([
    ['inexistente', null],
    ['desactivada', crearUsuario({ cuentaActiva: false })],
    ['sin verificar', crearUsuario({ correoVerificado: false })]
  ])('rechaza una cuenta %s', async (_caso, usuario) => {
    repo.buscarPorId.mockResolvedValue(usuario);

    await expect(refrescarToken('u1', 'refresh')).rejects.toMatchObject({ statusCode: 401 });
    expect(rotarTokenRenovacion).not.toHaveBeenCalled();
  });

  it('rechaza un refresh token ya usado o vencido', async () => {
    repo.buscarPorId.mockResolvedValue(crearUsuario());
    (rotarTokenRenovacion as jest.Mock).mockResolvedValue(false);

    await expect(refrescarToken('u1', 'refresh')).rejects.toMatchObject({ statusCode: 401 });
  });

  it('rota el refresh token y firma un token con la version de sesion vigente', async () => {
    repo.buscarPorId.mockResolvedValue(crearUsuario());
    (rotarTokenRenovacion as jest.Mock).mockResolvedValue(true);

    const { token, refreshToken } = await refrescarToken('u1', 'refresh-anterior');

    expect(rotarTokenRenovacion).toHaveBeenCalledWith('u1', 'refresh-anterior', refreshToken, 3);
    expect(refreshToken).not.toBe('refresh-anterior');
    expect(jwt.verify(token, entorno.jwt.secreto)).toMatchObject({
      usuarioId: 'u1',
      rol: 'ESTUDIANTE',
      versionSesion: 3
    });
  });
});

describe('cerrarSesion', () => {
  it('con refresh token revoca solo ese dispositivo', async () => {
    await cerrarSesion('u1', 'refresh');

    expect(revocarTokenRenovacion).toHaveBeenCalledWith('u1', 'refresh');
    expect(revocarTodosLosTokensRenovacion).not.toHaveBeenCalled();
    expect(olvidarDispositivosDeUsuario).toHaveBeenCalledWith('u1');
    expect(repo.actualizar).toHaveBeenCalledWith('u1', { versionSesion: { increment: 1 } });
  });

  it('sin refresh token revoca todas las sesiones', async () => {
    const resultado = await cerrarSesion('u1');

    expect(revocarTodosLosTokensRenovacion).toHaveBeenCalledWith('u1');
    expect(registrarAuditoria).toHaveBeenCalledWith(expect.objectContaining({ accion: 'LOGOUT' }));
    expect(resultado.message).toBe('Sesión cerrada correctamente');
    expect(liberarBicicleteroGuardia).not.toHaveBeenCalled();
  });

  it('un guardia que cierra sesión deja libre su bicicletero', async () => {
    await cerrarSesion('u1', 'refresh', 'GUARDIA');

    expect(liberarBicicleteroGuardia).toHaveBeenCalledWith('u1');
  });
});

describe('resultado del cambio de contraseña', () => {
  it('distingue la activación de un cambio normal', async () => {
    repo.buscarPorTokenCambioContrasena.mockResolvedValue(crearUsuario());
    await expect(cambiarContrasena('token', 'Nueva#Clave2026')).resolves.toEqual({
      message: 'Contraseña actualizada correctamente',
      activacion: false
    });

    repo.buscarPorTokenCambioContrasena.mockResolvedValue(
      crearUsuario({ debeCambiarContrasena: true })
    );
    await expect(cambiarContrasena('token', 'Nueva#Clave2026')).resolves.toEqual({
      message: 'Cuenta activada correctamente. Ya puedes iniciar sesión.',
      activacion: true
    });
  });
});

describe('revisarEnlaceCuenta', () => {
  it('un enlace de contraseña vigente indica la cuenta y si es activación', async () => {
    repo.buscarPorTokenCambioContrasena.mockResolvedValue(
      crearUsuario({ debeCambiarContrasena: true })
    );

    await expect(revisarEnlaceCuenta('cambiar-contrasena', 'token')).resolves.toEqual({
      valido: true,
      correo: 'ana@alumnos.ubiobio.cl',
      activacion: true
    });
    expect(repo.buscarPorTokenCambioContrasena).toHaveBeenCalledWith(hashearToken('token'));
  });

  it('un enlace de contraseña inexistente o ya usado no es válido', async () => {
    repo.buscarPorTokenCambioContrasena.mockResolvedValue(null);

    await expect(revisarEnlaceCuenta('cambiar-contrasena', 'token')).resolves.toMatchObject({
      valido: false,
      titulo: 'Enlace no válido'
    });
  });

  it('un enlace vencido orienta según sea activación o recuperación', async () => {
    repo.buscarPorTokenCambioContrasena.mockResolvedValue(
      crearUsuario({ debeCambiarContrasena: true, tokenCambioContrasenaExpiraEn: enMinutos(-1) })
    );
    await expect(revisarEnlaceCuenta('cambiar-contrasena', 'token')).resolves.toMatchObject({
      valido: false,
      titulo: 'Enlace vencido',
      mensaje: expect.stringContaining('El enlace para activar tu cuenta venció')
    });

    repo.buscarPorTokenCambioContrasena.mockResolvedValue(
      crearUsuario({ tokenCambioContrasenaExpiraEn: enMinutos(-1) })
    );
    await expect(revisarEnlaceCuenta('cambiar-contrasena', 'token')).resolves.toMatchObject({
      mensaje: expect.stringContaining('¿Has olvidado tu contraseña?')
    });
  });

  it('revisa el enlace de registro parcial', async () => {
    repo.buscarRegistroParcialPorToken.mockResolvedValue(crearUsuario({ registroParcial: true }));
    await expect(revisarEnlaceCuenta('completar-registro', 'token')).resolves.toMatchObject({
      valido: true,
      activacion: true
    });

    repo.buscarRegistroParcialPorToken.mockResolvedValue(
      crearUsuario({ registroParcial: true, tokenVerificacionCorreoExpiraEn: enMinutos(-5) })
    );
    await expect(revisarEnlaceCuenta('completar-registro', 'token')).resolves.toMatchObject({
      titulo: 'Enlace vencido'
    });

    repo.buscarRegistroParcialPorToken.mockResolvedValue(null);
    await expect(revisarEnlaceCuenta('completar-registro', 'token')).resolves.toMatchObject({
      titulo: 'Enlace no válido'
    });
  });

  it('revisa el enlace de verificación sin consumirlo', async () => {
    repo.buscarPorTokenVerificacion.mockResolvedValue(crearUsuario({ correoVerificado: false }));
    await expect(revisarEnlaceCuenta('verificar-correo', 'token')).resolves.toEqual({
      valido: true,
      correo: 'ana@alumnos.ubiobio.cl',
      activacion: false
    });

    repo.buscarPorTokenVerificacion.mockResolvedValue(
      crearUsuario({ tokenVerificacionCorreoExpiraEn: enMinutos(-1) })
    );
    await expect(revisarEnlaceCuenta('verificar-correo', 'token')).resolves.toMatchObject({
      titulo: 'Enlace vencido',
      reenviable: true
    });

    repo.buscarPorTokenVerificacion.mockResolvedValue(crearUsuario({ registroParcial: true }));
    await expect(revisarEnlaceCuenta('verificar-correo', 'token')).resolves.toMatchObject({
      titulo: 'Enlace no válido'
    });

    expect(repo.limpiarTokenVerificacion).not.toHaveBeenCalled();
    expect(repo.marcarCorreoVerificado).not.toHaveBeenCalled();
  });
});

describe('reenvío del enlace para confirmar el correo', () => {
  const pendiente = (cambios: Record<string, unknown> = {}) =>
    crearUsuario({
      correoVerificado: false,
      tokenVerificacionCorreoExpiraEn: enMinutos(-60),
      ...cambios
    });

  it('envía un enlace nuevo a una cuenta pendiente y responde siempre lo mismo', async () => {
    repo.buscarPorCorreo.mockResolvedValue(pendiente());

    await expect(reenviarVerificacion(' Ana@Alumnos.ubiobio.cl ')).resolves.toEqual({
      message: mensajeReenvioVerificacion
    });

    expect(repo.buscarPorCorreo).toHaveBeenCalledWith('ana@alumnos.ubiobio.cl');
    expect(repo.actualizar).toHaveBeenCalledWith(
      'u1',
      expect.objectContaining({
        tokenVerificacionCorreo: expect.any(String),
        tokenVerificacionCorreoExpiraEn: expect.any(Date)
      })
    );
    expect(crearCorreoVerificacion).toHaveBeenCalledWith(
      'Ana Rojas',
      'ana@alumnos.ubiobio.cl',
      expect.stringContaining('/enlaces/verificar-correo?token='),
      expect.any(Date)
    );
    expect(enviarCorreo).toHaveBeenCalledWith(
      expect.objectContaining({ para: 'ana@alumnos.ubiobio.cl' })
    );
    expect(registrarAuditoria).toHaveBeenCalledWith(
      expect.objectContaining({ accion: 'CORREO_VERIFICACION_REENVIADO' })
    );
  });

  it.each<[string, unknown]>([
    ['no existe', null],
    ['ya confirmó su correo', crearUsuario()],
    ['está desactivada', pendiente({ cuentaActiva: false })],
    ['es un registro parcial', pendiente({ registroParcial: true })],
    ['espera crear su contraseña', pendiente({ debeCambiarContrasena: true })],
    ['fue eliminada', pendiente({ eliminadoEn: new Date() })]
  ])('no envía nada si la cuenta %s', async (_caso, usuario) => {
    repo.buscarPorCorreo.mockResolvedValue(usuario as never);

    await expect(reenviarVerificacion('ana@alumnos.ubiobio.cl')).resolves.toEqual({
      message: mensajeReenvioVerificacion
    });
    expect(enviarCorreo).not.toHaveBeenCalled();
  });

  it('espera un minuto entre un envío y otro', async () => {
    repo.buscarPorCorreo.mockResolvedValue(
      pendiente({ tokenVerificacionCorreoExpiraEn: enMinutos(24 * 60 - 0.5) })
    );

    await reenviarVerificacion('ana@alumnos.ubiobio.cl');

    expect(repo.actualizar).not.toHaveBeenCalled();
    expect(enviarCorreo).not.toHaveBeenCalled();
  });

  it('desde un enlace vencido envía uno nuevo', async () => {
    repo.buscarPorTokenVerificacion.mockResolvedValue(pendiente());

    await expect(reenviarVerificacionConEnlace('token')).resolves.toBe(true);
    expect(repo.buscarPorTokenVerificacion).toHaveBeenCalledWith(hashearToken('token'));
    expect(enviarCorreo).toHaveBeenCalledTimes(1);
  });

  it('desde un enlace ya usado no envía nada', async () => {
    repo.buscarPorTokenVerificacion.mockResolvedValue(null);

    await expect(reenviarVerificacionConEnlace('token')).resolves.toBe(false);
    expect(enviarCorreo).not.toHaveBeenCalled();
  });
});
