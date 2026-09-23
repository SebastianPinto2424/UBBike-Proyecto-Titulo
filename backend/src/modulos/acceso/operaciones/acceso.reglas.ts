import { ErrorHttp } from '../../../comun/errors/error-http';
import { TipoMovimiento } from '../../historial/tipo-movimiento';

type BicicletaConEstado = {
  dentroBicicletero: boolean;
  bicicleteroActualId?: string | null;
};

export const validarReglaMovimiento = (bicicleta: BicicletaConEstado, tipo: TipoMovimiento) => {
  if (tipo === TipoMovimiento.INGRESO && bicicleta.dentroBicicletero) {
    throw new ErrorHttp(409, 'La bicicleta ya registra ingreso activo');
  }

  if (tipo === TipoMovimiento.RETIRO && !bicicleta.dentroBicicletero) {
    throw new ErrorHttp(409, 'La bicicleta no registra ingreso activo');
  }
};

export const validarBicicleteroDelRetiro = (
  bicicleta: BicicletaConEstado,
  tipo: TipoMovimiento,
  bicicleteroId: string
) => {
  if (tipo !== TipoMovimiento.RETIRO) {
    return;
  }

  if (bicicleta.bicicleteroActualId && bicicleta.bicicleteroActualId !== bicicleteroId) {
    throw new ErrorHttp(
      409,
      'La bicicleta está registrada en otro bicicletero. El retiro debe hacerse donde ingresó.'
    );
  }
};
