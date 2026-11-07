import '../apoyo/configurar-entorno';

jest.mock('bcrypt', () => ({ hash: jest.fn(async () => 'hash') }));

jest.mock('../../src/comun/utilidades/bloqueos', () => ({
  bloquearClave: jest.fn().mockResolvedValue(undefined),
  bloquearFila: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/acceso/operaciones/acceso.repositorio', () => ({
  ejecutarEnTransaccion: jest.fn(),
  buscarAsignacionActiva: jest.fn(),
  buscarAsignacionActivaConBicicletero: jest.fn(),
  buscarBicicletero: jest.fn(),
  contarOcupacion: jest.fn(),
  moverBicicletaSiCoincide: jest.fn(),
  crearMovimiento: jest.fn(),
  actualizarBicicleta: jest.fn(),
  buscarMovimientoCompleto: jest.fn(),
  desactivarBicicletasDeUsuario: jest.fn(),
  crearBicicleta: jest.fn(),
  buscarUsuarioPorCriterios: jest.fn(),
  crearUsuario: jest.fn(),
  actualizarUsuario: jest.fn(),
  buscarBicicletaParaGestionManual: jest.fn()
}));

jest.mock('../../src/modulos/bicicletas/foto-bicicleta.servicio', () => ({
  guardarFotoBicicleta: jest.fn().mockResolvedValue({
    fotoUrl: '/uploads/bicicletas/n1.jpg',
    fotoNombreArchivo: 'n1.jpg',
    fotoMimeType: 'image/jpeg',
    fotoTamanoBytes: 100,
    fotoActualizadaEn: new Date()
  })
}));

jest.mock('../../src/modulos/correos/cuenta.plantillas', () => ({
  crearCorreoCompletarRegistro: jest.fn().mockReturnValue({ asunto: 'a', texto: 't', html: 'h' })
}));

jest.mock('../../src/modulos/correos/operacion.plantillas', () => ({
  crearCorreoMovimiento: jest.fn().mockReturnValue({ asunto: 'a', texto: 't', html: 'h' })
}));

jest.mock('../../src/modulos/correos/correo.servicio', () => ({
  enviarCorreo: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/auditoria/auditoria.servicio', () => ({
  registrarAuditoria: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/tiempo-real/tiempo-real', () => ({
  EventosTiempoReal: { MOVIMIENTO: 'movimiento', BICICLETEROS: 'bicicleteros' },
  emitirTiempoReal: jest.fn(),
  emitirATodos: jest.fn(),
  salaRol: (rol: string) => `rol:${rol}`,
  salaUsuario: (id: string) => `usuario:${id}`
}));

import * as accesoRepositorio from '../../src/modulos/acceso/operaciones/acceso.repositorio';
import { registrarGestionManual } from '../../src/modulos/acceso/operaciones/gestion-manual.servicio';
import { crearCorreoCompletarRegistro } from '../../src/modulos/correos/cuenta.plantillas';
import { enviarCorreo } from '../../src/modulos/correos/correo.servicio';
import { TipoMovimiento } from '../../src/modulos/historial/tipo-movimiento';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';
import { emitirATodos } from '../../src/tiempo-real/tiempo-real';

const repo = accesoRepositorio as jest.Mocked<typeof accesoRepositorio>;

const rack = { id: 'r1', nombre: 'Biblioteca Central', activo: true, capacidad: 20 };
const usuario = {
  id: 'u1',
  nombre: 'Ana Rojas',
  correo: 'ana@alumnos.ubiobio.cl',
  rut: '11.111.111-1',
  registroParcial: false
};
const bici = (cambios: Record<string, unknown> = {}) => ({
  id: 'b1',
  descripcion: 'Urbana azul',
  dentroBicicletero: false,
  bicicleteroActualId: null,
  bicicleteroActual: null,
  ...cambios
});

const movimiento = (estado: 'CONFIRMADO' | 'DENEGADO', tipo = 'INGRESO') => ({
  id: 'm1',
  tipo,
  estado,
  origen: 'MANUAL',
  motivoDenegacion: estado === 'DENEGADO' ? 'Datos no coinciden' : null,
  comentarioGuardia: null,
  creadoEn: new Date(),
  usuario: { ...usuario },
  bicicleta: { ...bici(), fotoNombreArchivo: null },
  bicicletero: rack,
  validadoPorGuardia: { id: 'g1', nombre: 'Pedro Soto', correo: 'guardia@ubiobio.cl' }
});

const base = {
  guardiaId: 'g1',
  rol: RolUsuario.GUARDIA,
  correo: 'ana@alumnos.ubiobio.cl',
  tipo: TipoMovimiento.INGRESO,
  bicicleteroId: 'r1'
};

const datosBiciNueva = {
  crearBicicletaNueva: true,
  bicicletaDescripcion: 'Urbana azul',
  bicicletaMarca: 'Oxford',
  bicicletaModelo: 'Venus',
  bicicletaColor: 'Azul',
  bicicletaAro: '26',
  bicicletaNumeroSerie: 'SN1',
  bicicletaFotoUrl: 'data:image/jpeg;base64,AAAA'
};

beforeEach(() => {
  repo.ejecutarEnTransaccion.mockImplementation(((callback: (db: unknown) => unknown) =>
    callback({})) as never);
  repo.buscarUsuarioPorCriterios.mockResolvedValue(usuario as never);
  repo.buscarBicicletaParaGestionManual.mockResolvedValue(bici() as never);
  repo.buscarBicicletero.mockResolvedValue(rack as never);
  repo.buscarAsignacionActiva.mockResolvedValue({ id: 'a1' } as never);
  repo.contarOcupacion.mockResolvedValue(3);
  repo.moverBicicletaSiCoincide.mockResolvedValue({ count: 1 } as never);
  repo.crearMovimiento.mockResolvedValue({ id: 'm1' } as never);
  repo.buscarMovimientoCompleto.mockResolvedValue(movimiento('CONFIRMADO') as never);
  repo.crearBicicleta.mockResolvedValue(bici({ id: 'n1' }) as never);
});

describe('validaciones de la gestión manual', () => {
  it('exige correo o RUT', async () => {
    await expect(registrarGestionManual({ ...base, correo: undefined })).rejects.toMatchObject({
      statusCode: 400
    });
  });

  it('un retiro de alguien sin cuenta responde 404', async () => {
    repo.buscarUsuarioPorCriterios.mockResolvedValue(null);

    await expect(
      registrarGestionManual({ ...base, rut: '11.111.111-1', tipo: TipoMovimiento.RETIRO })
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it('para crear a alguien nuevo exige correo y RUT', async () => {
    repo.buscarUsuarioPorCriterios.mockResolvedValue(null);

    await expect(registrarGestionManual(base)).rejects.toMatchObject({ statusCode: 400 });
  });

  it('un registro parcial no puede retirar', async () => {
    repo.buscarUsuarioPorCriterios.mockResolvedValue({
      ...usuario,
      registroParcial: true
    } as never);

    await expect(
      registrarGestionManual({ ...base, tipo: TipoMovimiento.RETIRO })
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it('no permite elegir y crear bicicleta a la vez', async () => {
    await expect(
      registrarGestionManual({ ...base, ...datosBiciNueva, bicicletaId: 'b1' })
    ).rejects.toMatchObject({ statusCode: 400 });
  });

  it('un retiro sin bicicleta activa responde 404', async () => {
    repo.buscarBicicletaParaGestionManual.mockResolvedValue(null);

    await expect(
      registrarGestionManual({ ...base, tipo: TipoMovimiento.RETIRO })
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it('una bicicleta nueva necesita todos sus datos y foto', async () => {
    repo.buscarBicicletaParaGestionManual.mockResolvedValue(null);

    await expect(
      registrarGestionManual({ ...base, ...datosBiciNueva, bicicletaFotoUrl: undefined })
    ).rejects.toMatchObject({ statusCode: 400 });
  });
});

describe('bicicletero de la operación', () => {
  it('el guardia debe estar asignado al bicicletero', async () => {
    repo.buscarAsignacionActiva.mockResolvedValue(null);

    await expect(registrarGestionManual(base)).rejects.toMatchObject({ statusCode: 403 });
  });

  it('no opera en un bicicletero inactivo', async () => {
    repo.buscarBicicletero.mockResolvedValue({ ...rack, activo: false } as never);

    await expect(registrarGestionManual(base)).rejects.toMatchObject({ statusCode: 409 });
  });

  it('responde 404 si el bicicletero no existe', async () => {
    repo.buscarBicicletero.mockResolvedValue(null);

    await expect(registrarGestionManual(base)).rejects.toMatchObject({ statusCode: 404 });
  });

  it('sin bicicletero indicado usa la asignación del guardia', async () => {
    repo.buscarAsignacionActivaConBicicletero.mockResolvedValue({ bicicletero: rack } as never);

    await registrarGestionManual({ ...base, bicicleteroId: undefined });

    expect(repo.buscarBicicletero).toHaveBeenCalledWith('r1', {});
  });

  it('sin bicicletero ni asignación pide indicarlo', async () => {
    repo.buscarAsignacionActivaConBicicletero.mockResolvedValue(null);

    await expect(
      registrarGestionManual({ ...base, bicicleteroId: undefined })
    ).rejects.toMatchObject({ statusCode: 400 });
  });

  it('el administrador no necesita asignación', async () => {
    repo.buscarAsignacionActiva.mockResolvedValue(null);

    await registrarGestionManual({ ...base, rol: RolUsuario.ADMINISTRADOR });

    expect(repo.buscarAsignacionActiva).not.toHaveBeenCalled();
  });
});

describe('reglas del movimiento', () => {
  it('no ingresa una bicicleta que ya está dentro', async () => {
    repo.buscarBicicletaParaGestionManual.mockResolvedValue(
      bici({ dentroBicicletero: true, bicicleteroActualId: 'r1' }) as never
    );

    await expect(registrarGestionManual(base)).rejects.toMatchObject({ statusCode: 409 });
  });

  it('el retiro debe hacerse en el bicicletero donde ingresó', async () => {
    repo.buscarBicicletaParaGestionManual.mockResolvedValue(
      bici({ dentroBicicletero: true, bicicleteroActualId: 'r2' }) as never
    );

    await expect(
      registrarGestionManual({ ...base, tipo: TipoMovimiento.RETIRO })
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it('un bicicletero lleno no acepta ingresos', async () => {
    repo.contarOcupacion.mockResolvedValue(20);

    await expect(registrarGestionManual(base)).rejects.toMatchObject({ statusCode: 409 });
  });

  it('detecta si la bicicleta cambió de estado a la vez', async () => {
    repo.moverBicicletaSiCoincide.mockResolvedValue({ count: 0 } as never);

    await expect(registrarGestionManual(base)).rejects.toMatchObject({ statusCode: 409 });
  });
});

describe('registro del movimiento', () => {
  it('un ingreso confirmado mueve la bicicleta y actualiza la ocupación', async () => {
    const resultado = await registrarGestionManual({ ...base, comentario: '  sin novedad ' });

    expect(repo.crearMovimiento).toHaveBeenCalledWith(
      expect.objectContaining({
        estado: 'CONFIRMADO',
        origen: 'MANUAL',
        comentarioGuardia: 'sin novedad'
      }),
      {}
    );
    expect(repo.moverBicicletaSiCoincide).toHaveBeenCalledWith(
      'b1',
      false,
      null,
      { dentroBicicletero: true, bicicleteroActualId: 'r1' },
      {}
    );
    expect(emitirATodos).toHaveBeenCalledWith('bicicleteros');
    expect(resultado).toMatchObject({ id: 'm1', estado: 'CONFIRMADO' });
  });

  it('un retiro confirmado saca la bicicleta del bicicletero', async () => {
    repo.buscarBicicletaParaGestionManual.mockResolvedValue(
      bici({ dentroBicicletero: true, bicicleteroActualId: 'r1' }) as never
    );
    repo.buscarMovimientoCompleto.mockResolvedValue(movimiento('CONFIRMADO', 'RETIRO') as never);

    await registrarGestionManual({ ...base, tipo: TipoMovimiento.RETIRO });

    expect(repo.moverBicicletaSiCoincide).toHaveBeenCalledWith(
      'b1',
      true,
      'r1',
      { dentroBicicletero: false, bicicleteroActualId: null },
      {}
    );
  });

  it('una denegación queda registrada sin mover la bicicleta', async () => {
    repo.buscarBicicletaParaGestionManual.mockResolvedValue(
      bici({ dentroBicicletero: true, bicicleteroActualId: 'r1' }) as never
    );
    repo.buscarMovimientoCompleto.mockResolvedValue(movimiento('DENEGADO') as never);

    await registrarGestionManual({ ...base, denegar: true, motivo: 'Datos no coinciden' });

    expect(repo.crearMovimiento).toHaveBeenCalledWith(
      expect.objectContaining({ estado: 'DENEGADO', motivoDenegacion: 'Datos no coinciden' }),
      {}
    );
    expect(repo.moverBicicletaSiCoincide).not.toHaveBeenCalled();
  });

  it('una persona nueva queda con registro parcial y recibe el enlace', async () => {
    repo.buscarUsuarioPorCriterios.mockResolvedValue(null);
    repo.crearUsuario.mockResolvedValue({ ...usuario, id: 'u9', registroParcial: true } as never);
    repo.buscarBicicletaParaGestionManual.mockResolvedValue(null);

    await registrarGestionManual({
      ...base,
      correo: 'Nueva.Persona@Alumnos.Ubiobio.cl',
      rut: '11.111.111-1',
      ...datosBiciNueva
    });

    expect(repo.crearUsuario).toHaveBeenCalledWith(
      expect.objectContaining({
        correo: 'nueva.persona@alumnos.ubiobio.cl',
        rol: RolUsuario.ESTUDIANTE,
        registroParcial: true,
        correoVerificado: false,
        nombre: 'Registro pendiente'
      }),
      {}
    );
    expect(repo.desactivarBicicletasDeUsuario).toHaveBeenCalledWith('u9', {});
    expect(repo.actualizarBicicleta).toHaveBeenCalledWith(
      'n1',
      expect.objectContaining({ fotoNombreArchivo: 'n1.jpg' }),
      {}
    );
    const enlace = (crearCorreoCompletarRegistro as jest.Mock).mock.calls[0][1] as string;
    expect(enlace).toMatch(/\/enlaces\/completar-registro\?token=[a-f0-9]{64}$/);
    expect(enviarCorreo).toHaveBeenCalledWith(
      expect.objectContaining({ para: 'nueva.persona@alumnos.ubiobio.cl' }),
      {}
    );
  });

  it('a un registro parcial que ingresa se le renueva el enlace', async () => {
    repo.buscarUsuarioPorCriterios.mockResolvedValue({
      ...usuario,
      registroParcial: true
    } as never);
    repo.actualizarUsuario.mockResolvedValue({ ...usuario, registroParcial: true } as never);

    await registrarGestionManual(base);

    expect(repo.actualizarUsuario).toHaveBeenCalledWith(
      'u1',
      expect.objectContaining({ tokenVerificacionCorreo: expect.any(String) }),
      {}
    );
    expect(crearCorreoCompletarRegistro).toHaveBeenCalledWith(
      'ana@alumnos.ubiobio.cl',
      expect.stringContaining('/enlaces/completar-registro?token=')
    );
  });
});
