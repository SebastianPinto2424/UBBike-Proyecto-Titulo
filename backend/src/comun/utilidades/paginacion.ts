import { ErrorHttp } from '../errores/error-http';

export const limitarPagina = (valor: number | undefined, defecto = 20, maximo = 100) => {
  if (valor === undefined) return defecto;
  if (!Number.isSafeInteger(valor) || valor < 1) {
    throw new ErrorHttp(400, 'El límite debe ser un entero positivo');
  }
  return Math.min(valor, maximo);
};

export const validarCursor = (cursor?: string) => {
  if (cursor && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(cursor)) {
    throw new ErrorHttp(400, 'Cursor de paginación inválido');
  }
};
