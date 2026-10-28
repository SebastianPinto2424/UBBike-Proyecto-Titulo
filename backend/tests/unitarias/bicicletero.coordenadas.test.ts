import {
  esquemaCrearBicicletero,
  esquemaActualizarBicicletero
} from '../../src/modulos/bicicleteros/bicicletero.validacion';

const base = { nombre: 'Bicicletero FACE', ubicacion: 'Acceso principal', capacidad: 80 };
describe.each([esquemaCrearBicicletero, esquemaActualizarBicicletero])(
  'coordenadas del formulario',
  (esquema) => {
    it.each([
      {},
      { latitud: -36.82, longitud: -73.01 },
      { latitud: 0, longitud: 0 },
      { latitud: null, longitud: null },
      { latitud: -90, longitud: 180 }
    ])('acepta el par o su ausencia: %j', (coordenadas) => {
      expect(esquema.validate({ ...base, ...coordenadas }).error).toBeUndefined();
    });
    it.each([
      { latitud: -36 },
      { longitud: -73 },
      { latitud: null, longitud: -73 },
      { latitud: -36, longitud: null },
      { latitud: 91, longitud: 0 },
      { latitud: 0, longitud: -181 },
      { latitud: NaN, longitud: 0 },
      { latitud: Infinity, longitud: 0 }
    ])('rechaza coordenadas incompletas o inválidas: %j', (coordenadas) => {
      expect(esquema.validate({ ...base, ...coordenadas }).error).toBeDefined();
    });
  }
);
