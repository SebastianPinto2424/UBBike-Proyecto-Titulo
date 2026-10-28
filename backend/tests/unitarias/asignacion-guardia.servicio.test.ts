import '../apoyo/configurar-entorno';
import { prismaSimulado } from '../apoyo/prisma-simulado';
jest.mock('../../src/modulos/notificaciones/notificacion.servicio', () => ({
  crearNotificacion: jest.fn(),
  notificarUsuariosPorRol: jest.fn(),
  ejecutarEfectosDiferidos: jest.fn()
}));
import {
  asignarGuardiaABicicletero,
  seleccionarBicicleteroGuardia,
  liberarBicicleteroGuardia,
  liberarGuardiaDeBicicletero,
  listarGuardiasHabilitados
} from '../../src/modulos/acceso/asignaciones/asignacion-guardia.servicio';
import {
  crearNotificacion,
  notificarUsuariosPorRol
} from '../../src/modulos/notificaciones/notificacion.servicio';

const biblioteca = { id: 'rack', nombre: 'Biblioteca', activo: true, capacidad: 20 };

const avisos = () => jest.mocked(crearNotificacion).mock.calls.map(([datos]) => datos);
const avisosCentral = () => jest.mocked(notificarUsuariosPorRol).mock.calls.map(([datos]) => datos);

beforeEach(() => {
  prismaSimulado.solicitudGuardia.findMany.mockResolvedValue([]);
});

it('no asigna un bicicletero inexistente o inactivo', async () => {
  prismaSimulado.bicicletero.findFirst.mockResolvedValue(null);
  await expect(seleccionarBicicleteroGuardia('u', 'rack')).rejects.toMatchObject({
    statusCode: 404
  });
  expect(prismaSimulado.asignacionGuardia.create).not.toHaveBeenCalled();
});
it('libera asignaciones dentro de una transacción con bloqueo por guardia', async () => {
  await liberarBicicleteroGuardia('u');
  expect(prismaSimulado.$transaction).toHaveBeenCalled();
  expect(prismaSimulado.$queryRaw).toHaveBeenCalled();
  expect(prismaSimulado.asignacionGuardia.updateMany).toHaveBeenCalled();
});

it('no deja tomar un bicicletero que ya gestiona otro guardia', async () => {
  prismaSimulado.bicicletero.findFirst.mockResolvedValue({
    id: 'rack',
    nombre: 'Biblioteca',
    activo: true
  } as never);
  prismaSimulado.asignacionGuardia.findFirst.mockResolvedValue({
    guardiaId: 'otro',
    guardia: { nombre: 'Pedro Soto' }
  } as never);

  await expect(seleccionarBicicleteroGuardia('u', 'rack')).rejects.toMatchObject({
    statusCode: 409,
    message: 'Pedro Soto ya gestiona Biblioteca. Debe liberarlo antes de que puedas tomarlo.'
  });
  expect(prismaSimulado.asignacionGuardia.updateMany).not.toHaveBeenCalled();
  expect(prismaSimulado.asignacionGuardia.create).not.toHaveBeenCalled();
});

it('el guardia puede volver a elegir el bicicletero que ya gestiona', async () => {
  const bicicletero = { id: 'rack', nombre: 'Biblioteca', activo: true, capacidad: 20 };
  prismaSimulado.bicicletero.findFirst.mockResolvedValue(bicicletero as never);
  prismaSimulado.asignacionGuardia.findFirst.mockResolvedValue({
    guardiaId: 'u',
    guardia: { nombre: 'Ana Rojas' }
  } as never);
  prismaSimulado.asignacionGuardia.create.mockResolvedValue({
    id: 'a2',
    guardiaId: 'u',
    bicicleteroId: 'rack',
    iniciaEn: new Date()
  } as never);

  await seleccionarBicicleteroGuardia('u', 'rack');

  expect(prismaSimulado.asignacionGuardia.create).toHaveBeenCalled();
});

it('registra quién liberó el bicicletero cuando lo hace administración', async () => {
  await liberarBicicleteroGuardia('u', 'admin-1');

  expect(prismaSimulado.auditoriaEvento.create).toHaveBeenCalledWith(
    expect.objectContaining({
      data: expect.objectContaining({ actorUsuarioId: 'admin-1', entidadId: 'u' })
    })
  );
});

it('al tomar un bicicletero recibe las solicitudes que nadie atendía', async () => {
  prismaSimulado.bicicletero.findFirst.mockResolvedValue(biblioteca as never);
  prismaSimulado.asignacionGuardia.findFirst.mockResolvedValue(null);
  prismaSimulado.asignacionGuardia.create.mockResolvedValue({
    id: 'a1',
    guardiaId: 'u',
    bicicleteroId: 'rack',
    iniciaEn: new Date()
  } as never);
  prismaSimulado.solicitudGuardia.findMany.mockResolvedValueOnce([]).mockResolvedValueOnce([
    { id: 's1', solicitadaPorUsuarioId: 'p1' },
    { id: 's2', solicitadaPorUsuarioId: 'p2' }
  ] as never);

  await seleccionarBicicleteroGuardia('u', 'rack');

  expect(prismaSimulado.solicitudGuardia.updateMany).toHaveBeenCalledWith({
    where: { id: { in: ['s1', 's2'] } },
    data: expect.objectContaining({ guardiaAsignadoId: 'u', estado: 'NOTIFICADA' })
  });
  expect(avisos()).toContainEqual(
    expect.objectContaining({
      usuarioId: 'p1',
      mensaje: 'Un guardia recibió tu solicitud en Biblioteca.'
    })
  );
  expect(avisos()).toContainEqual(
    expect.objectContaining({
      usuarioId: 'u',
      titulo: 'Solicitudes pendientes',
      mensaje: 'Ahora gestionas Biblioteca durante tu turno. Tienes 2 solicitudes pendientes.',
      tipo: 'SOLICITUD_GUARDIA'
    })
  );
});

it('al liberar, las solicitudes sin respuesta vuelven a pendientes y se avisa a central', async () => {
  prismaSimulado.solicitudGuardia.findMany.mockResolvedValue([
    {
      id: 's1',
      solicitadaPorUsuarioId: 'p1',
      bicicletero: { id: 'rack', nombre: 'Biblioteca' },
      guardiaAsignado: { nombre: 'Ana Rojas' }
    }
  ] as never);

  await liberarBicicleteroGuardia('u');

  expect(prismaSimulado.solicitudGuardia.updateMany).toHaveBeenCalledWith({
    where: { id: { in: ['s1'] } },
    data: { guardiaAsignadoId: null, estado: 'PENDIENTE' }
  });
  expect(avisosCentral()).toContainEqual(
    expect.objectContaining({
      mensaje: 'Ana Rojas dejó de gestionar Biblioteca. Hay 1 solicitud pendiente sin guardia.'
    })
  );
  expect(avisos()).toContainEqual(
    expect.objectContaining({ usuarioId: 'p1', titulo: 'Solicitud pendiente' })
  );
});

it('central libera el bicicletero de un guardia y le avisa', async () => {
  prismaSimulado.asignacionGuardia.findFirst.mockResolvedValue({
    id: 'a1',
    guardiaId: 'g1',
    guardia: { nombre: 'Pedro Soto' },
    bicicletero: { nombre: 'Biblioteca' }
  } as never);
  prismaSimulado.asignacionGuardia.updateMany.mockResolvedValue({ count: 1 });

  await expect(liberarGuardiaDeBicicletero('rack', 'central-1')).resolves.toEqual({
    message: 'Bicicletero liberado'
  });
  expect(prismaSimulado.asignacionGuardia.updateMany).toHaveBeenCalledWith({
    where: { id: 'a1', activa: true },
    data: expect.objectContaining({ activa: false })
  });
  expect(avisos()).toContainEqual(
    expect.objectContaining({
      usuarioId: 'g1',
      mensaje: 'Central liberó Biblioteca. Ya no lo gestionas.',
      push: true
    })
  );
  expect(prismaSimulado.auditoriaEvento.create).toHaveBeenCalledWith(
    expect.objectContaining({
      data: expect.objectContaining({ actorUsuarioId: 'central-1', entidadId: 'g1' })
    })
  );
});

it('central no puede liberar un bicicletero que nadie gestiona', async () => {
  prismaSimulado.asignacionGuardia.findFirst.mockResolvedValue(null);

  await expect(liberarGuardiaDeBicicletero('rack', 'central-1')).rejects.toMatchObject({
    statusCode: 409,
    message: 'Nadie gestiona este bicicletero'
  });
});

it('si el guardia ya dejó el bicicletero no se cierra otra asignación', async () => {
  prismaSimulado.asignacionGuardia.findFirst.mockResolvedValue({
    id: 'a1',
    guardiaId: 'g1',
    guardia: { nombre: 'Pedro Soto' },
    bicicletero: { nombre: 'Biblioteca' }
  } as never);
  prismaSimulado.asignacionGuardia.updateMany.mockResolvedValue({ count: 0 });

  await expect(liberarGuardiaDeBicicletero('rack', 'central-1')).rejects.toMatchObject({
    statusCode: 409,
    message: 'Pedro Soto ya dejó Biblioteca'
  });
  expect(crearNotificacion).not.toHaveBeenCalled();
});

it('sin solicitudes pendientes el aviso de asignación queda solo en la app', async () => {
  prismaSimulado.bicicletero.findFirst.mockResolvedValue(biblioteca as never);
  prismaSimulado.asignacionGuardia.findFirst.mockResolvedValue(null);
  prismaSimulado.asignacionGuardia.create.mockResolvedValue({
    id: 'a1',
    guardiaId: 'u',
    bicicleteroId: 'rack',
    iniciaEn: new Date()
  } as never);

  await seleccionarBicicleteroGuardia('u', 'rack');

  expect(avisos()).toContainEqual(
    expect.objectContaining({ usuarioId: 'u', titulo: 'Bicicletero asignado', tipo: 'SISTEMA' })
  );
});

describe('central asigna guardias', () => {
  beforeEach(() => {
    prismaSimulado.bicicletero.findFirst.mockResolvedValue(biblioteca as never);
    prismaSimulado.asignacionGuardia.findFirst.mockResolvedValue(null);
    prismaSimulado.asignacionGuardia.create.mockResolvedValue({
      id: 'a3',
      guardiaId: 'g2',
      bicicleteroId: 'rack',
      iniciaEn: new Date()
    } as never);
  });

  it('asigna un guardia habilitado y le avisa por push', async () => {
    prismaSimulado.usuario.findFirst.mockResolvedValue({ id: 'g2', nombre: 'Ana Rojas' } as never);

    await asignarGuardiaABicicletero('rack', 'g2', 'central-1');

    expect(prismaSimulado.asignacionGuardia.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ guardiaId: 'g2', bicicleteroId: 'rack', activa: true })
    });
    expect(avisos()).toContainEqual(
      expect.objectContaining({
        usuarioId: 'g2',
        mensaje: 'Central te asignó Biblioteca.',
        push: true
      })
    );
    expect(prismaSimulado.auditoriaEvento.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          actorUsuarioId: 'central-1',
          accion: 'GUARDIA_BICICLETERO_ASIGNADO_POR_CENTRAL'
        })
      })
    );
  });

  it('no asigna a quien no es un guardia habilitado', async () => {
    prismaSimulado.usuario.findFirst.mockResolvedValue(null);

    await expect(asignarGuardiaABicicletero('rack', 'x', 'central-1')).rejects.toMatchObject({
      statusCode: 404
    });
    expect(prismaSimulado.asignacionGuardia.create).not.toHaveBeenCalled();
  });

  it('no asigna un bicicletero que ya gestiona otro guardia', async () => {
    prismaSimulado.usuario.findFirst.mockResolvedValue({ id: 'g2', nombre: 'Ana Rojas' } as never);
    prismaSimulado.asignacionGuardia.findFirst.mockResolvedValue({
      guardiaId: 'g9',
      guardia: { nombre: 'Pedro Soto' },
      bicicletero: { nombre: 'Biblioteca' }
    } as never);

    await expect(asignarGuardiaABicicletero('rack', 'g2', 'central-1')).rejects.toMatchObject({
      statusCode: 409,
      message: 'Pedro Soto ya gestiona Biblioteca. Libéralo antes de asignar a otro guardia.'
    });
    expect(prismaSimulado.asignacionGuardia.create).not.toHaveBeenCalled();
  });

  it('lista los guardias habilitados con el bicicletero que gestiona cada uno', async () => {
    prismaSimulado.usuario.findMany.mockResolvedValue([
      {
        id: 'g1',
        nombre: 'Ana Rojas',
        asignacionesGuardia: [{ bicicletero: { id: 'rack', nombre: 'Biblioteca' } }]
      },
      { id: 'g2', nombre: 'Pedro Soto', asignacionesGuardia: [] }
    ] as never);

    await expect(listarGuardiasHabilitados()).resolves.toEqual([
      { id: 'g1', nombre: 'Ana Rojas', bicicletero: { id: 'rack', nombre: 'Biblioteca' } },
      { id: 'g2', nombre: 'Pedro Soto', bicicletero: null }
    ]);
  });
});
