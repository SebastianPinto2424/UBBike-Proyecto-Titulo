import { CustomHelpers } from 'joi';

const PALABRA = "[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+(?:['-][A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*";

export const NOMBRE_COMPLETO = new RegExp(`^${PALABRA}(?: ${PALABRA}){3}$`);

export const validarNombreCompleto = (valor: string, helpers: CustomHelpers) => {
  const limpio = valor.trim().replace(/\s+/g, ' ');

  if (!NOMBRE_COMPLETO.test(limpio)) {
    return helpers.error('any.invalid');
  }

  return limpio;
};
