import { entorno } from '../../configuracion/entorno';

export const accionesEnlace = [
  'verificar-correo',
  'cambiar-contrasena',
  'completar-registro'
] as const;

export type AccionEnlace = (typeof accionesEnlace)[number];

export const resultadosEnlace = [
  'correo-verificado',
  'registro-completado',
  'cuenta-activada',
  'contrasena-actualizada',
  'enlace-reenviado'
] as const;

export type ResultadoEnlace = (typeof resultadosEnlace)[number];

export const esAccionEnlace = (valor: string): valor is AccionEnlace =>
  (accionesEnlace as readonly string[]).includes(valor);

export const esResultadoEnlace = (valor: string): valor is ResultadoEnlace =>
  (resultadosEnlace as readonly string[]).includes(valor);

export const crearEnlaceCorreo = (accion: AccionEnlace, token: string): string =>
  `${entorno.app.urlEnlaces}/enlaces/${accion}?${new URLSearchParams({ token }).toString()}`;
