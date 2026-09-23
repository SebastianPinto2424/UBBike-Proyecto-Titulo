import { CustomHelpers } from 'joi';

const agregarPuntos = (cuerpo: string): string => cuerpo.replace(/\B(?=(\d{3})+(?!\d))/g, '.');

export const normalizarRut = (cuerpo: string, dv: string): string =>
  `${agregarPuntos(cuerpo)}-${dv}`;

export const calcularDigitoVerificador = (cuerpo: string): string => {
  let suma = 0;
  let multiplicador = 2;

  for (let i = cuerpo.length - 1; i >= 0; i -= 1) {
    suma += Number(cuerpo[i]) * multiplicador;
    multiplicador = multiplicador === 7 ? 2 : multiplicador + 1;
  }

  const esperado = 11 - (suma % 11);
  if (esperado === 11) {
    return '0';
  }
  if (esperado === 10) {
    return 'K';
  }
  return esperado.toString();
};

export const validarRutChileno = (valor: string, helpers: CustomHelpers) => {
  const limpio = valor.trim().toUpperCase();

  if (!/^[\d.]+-[\dK]$/.test(limpio)) {
    return helpers.error('any.invalid');
  }

  const [cuerpoRaw, dv] = limpio.split('-');
  const cuerpo = cuerpoRaw.replace(/\./g, '');

  if (!/^\d{7,8}$/.test(cuerpo)) {
    return helpers.error('any.invalid');
  }

  if (dv !== calcularDigitoVerificador(cuerpo)) {
    return helpers.error('any.invalid');
  }

  return normalizarRut(cuerpo, dv);
};
