import '../helpers/env-setup';
import '../helpers/prisma-mock';

jest.mock('../../src/modulos/correos/correo.servicio', () => ({
  crearCorreoCompletarRegistro: jest.fn(),
  crearCorreoMovimiento: jest.fn().mockReturnValue({ asunto: '', texto: '', html: '' }),
  enviarCorreo: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/auditoria/auditoria.servicio', () => ({
  registrarAuditoria: jest.fn().mockResolvedValue(undefined)
}));

jest.mock('../../src/modulos/qr/qr.servicio', () => ({
  obtenerCodigoQrEscaneadoParaMovimiento: jest.fn(),
  notificarEstadoQr: jest.fn()
}));

jest.mock('../../src/modulos/acceso/operaciones/acceso.repositorio', () => ({
  ejecutarEnTransaccion: jest.fn((callback: (db: unknown) => unknown) => callback({})),
  buscarBicicletero: jest.fn(),
  contarOcupacion: jest.fn(),
  moverBicicletaSiCoincide: jest.fn(),
  marcarQrUsado: jest.fn(),
  crearMovimiento: jest.fn(),
  buscarMovimientoCompleto: jest.fn()
}));

import * as accesoRepositorio from '../../src/modulos/acceso/operaciones/acceso.repositorio';
import { confirmarQr, denegarQr } from '../../src/modulos/acceso/operaciones/acceso.servicio';
import * as qrServicio from '../../src/modulos/qr/qr.servicio';
import { RolUsuario } from '../../src/modulos/usuarios/rol-usuario';

const repositorio = accesoRepositorio as jest.Mocked<typeof accesoRepositorio>;
const qr = qrServicio as jest.Mocked<typeof qrServicio>;

const bicicletero = { id: 'bicicletero-1', nombre: 'Central', activo: true, capacidad: 80 };
const usuario = { id: 'user-1', nombre: 'Juan', correo: 'juan@alumnos.ubiobio.cl', rut: null };
const bicicleta = {
  id: 'bici-1',
  descripcion: 'Bici roja',
  marca: null,
  modelo: null,
  color: null,
  aro: null,
  numeroSerie: null,
  fotoUrl: null,
  fotoNombreArchivo: null,
  dentroBicicletero: false,
  bicicleteroActualId: null,
  bicicleteroActual: null
};

const movimientoCompleto = (estado: 'CONFIRMADO' | 'DENEGADO', motivo: string | null) => ({
  id: 'mov-1',
  tipo: 'INGRESO',
  estado,
  origen: 'QR',
  motivoDenegacion: motivo,
  comentarioGuardia: null,
  creadoEn: new Date(),
  usuario,
  bicicleta,
  bicicletero,
  validadoPorGuardia: { id: 'admin-1', nombre: 'Admin', correo: 'admin@ubiobio.cl' }
});

const datosBase = {
  token: 'UBBIKE-token',
  guardiaId: 'admin-1',
  rol: RolUsuario.ADMINISTRADOR,
  bicicleteroId: 'bicicletero-1'
};

beforeEach(() => {
  jest.clearAllMocks();
  qr.obtenerCodigoQrEscaneadoParaMovimiento.mockResolvedValue({
    id: 'qr-1',
    tipo: 'INGRESO',
    usuario,
    bicicleta,
    bicicletero
  } as never);
  repositorio.buscarBicicletero.mockResolvedValue(bicicletero as never);
  repositorio.contarOcupacion.mockResolvedValue(0 as never);
  repositorio.moverBicicletaSiCoincide.mockResolvedValue({ count: 1 } as never);
  repositorio.marcarQrUsado.mockResolvedValue({ count: 1 } as never);
  repositorio.crearMovimiento.mockResolvedValue({ id: 'mov-1' } as never);
});

it('avisa al dueño del QR que su ingreso fue confirmado', async () => {
  repositorio.buscarMovimientoCompleto.mockResolvedValue(
    movimientoCompleto('CONFIRMADO', null) as never
  );

  await confirmarQr(datosBase);

  expect(qr.notificarEstadoQr).toHaveBeenCalledWith('user-1', {
    qrId: 'qr-1',
    estado: 'CONFIRMADO',
    tipo: 'INGRESO',
    motivo: null
  });
});

it('avisa al dueño del QR que su ingreso fue denegado, con el motivo', async () => {
  repositorio.buscarMovimientoCompleto.mockResolvedValue(
    movimientoCompleto('DENEGADO', 'Bicicleta no coincide') as never
  );

  await denegarQr({ ...datosBase, motivo: 'Bicicleta no coincide' });

  expect(qr.notificarEstadoQr).toHaveBeenCalledWith('user-1', {
    qrId: 'qr-1',
    estado: 'DENEGADO',
    tipo: 'INGRESO',
    motivo: 'Bicicleta no coincide'
  });
});

it('no avisa si el QR ya habia sido usado', async () => {
  repositorio.marcarQrUsado.mockResolvedValue({ count: 0 } as never);

  await expect(confirmarQr(datosBase)).rejects.toMatchObject({ statusCode: 409 });
  expect(qr.notificarEstadoQr).not.toHaveBeenCalled();
});
