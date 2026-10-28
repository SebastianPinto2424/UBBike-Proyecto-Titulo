import '../apoyo/configurar-entorno';
import '../apoyo/prisma-simulado';
import { prismaSimulado } from '../apoyo/prisma-simulado';

jest.mock('../../src/modulos/bicicletas/foto-bicicleta.servicio', () => ({
  guardarFotoBicicleta: jest.fn(),
  eliminarArchivoFotoBicicleta: jest.fn().mockResolvedValue(undefined)
}));

import { crearBicicleta } from '../../src/modulos/bicicletas/bicicleta.servicio';

const biciGuardada = {
  id: 'bici-nueva',
  usuarioId: 'user-1',
  descripcion: 'Bici nueva',
  marca: null,
  modelo: null,
  color: null,
  aro: null,
  numeroSerie: null,
  fotoUrl: null,
  fotoNombreArchivo: null,
  fotoMimeType: null,
  fotoTamanoBytes: null,
  fotoActualizadaEn: null,
  activa: false,
  dentroBicicletero: false,
  bicicleteroActualId: null,
  creadoEn: new Date(),
  actualizadoEn: new Date(),
  eliminadoEn: null,
  bicicleteroActual: null
};

describe('crearBicicleta', () => {
  it('crea la bici INACTIVA y la activa vía dejarSoloActiva aunque el usuario ya tenga otra activa', async () => {
    prismaSimulado.bicicleta.count.mockResolvedValue(1);
    prismaSimulado.bicicleta.create.mockResolvedValue(biciGuardada as never);
    prismaSimulado.bicicleta.updateMany.mockResolvedValue({ count: 1 } as never);
    prismaSimulado.bicicleta.update.mockResolvedValue(biciGuardada as never);
    prismaSimulado.bicicleta.findFirst.mockResolvedValue(biciGuardada as never);

    await crearBicicleta({ usuarioId: 'user-1', descripcion: 'Bici nueva', activar: true });

    expect(prismaSimulado.bicicleta.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ activa: false }) })
    );
    expect(prismaSimulado.bicicleta.updateMany).toHaveBeenCalled();
    expect(prismaSimulado.bicicleta.update).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 'bici-nueva' }, data: { activa: true } })
    );
  });
});
